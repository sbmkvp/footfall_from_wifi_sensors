# ==============================================================================
# Setup the environment
# ==============================================================================

rm(list = ls())
options(width = as.integer(Sys.getenv("COLUMNS")))

# ==============================================================================
# Load required libraries and submodules
# ==============================================================================

library(tidyverse)
library(classInt)
library(ggplot2)
source("datacleaning_utils.r")

# ==============================================================================
# Global variables
# ==============================================================================

file <- "../data/final_data.csv"
filter_signal_value <- NULL
filter_signal_algorithm <- "kmeans"
filter_vendor_table <- "../data/final_vendors.csv"

# ==============================================================================
# Read the data file and do basic formatting for legible display
# ==============================================================================

data_00 <- 
	file %>%
	read.csv(stringsAsFactors = FALSE) %>%
	as_tibble() %>%
	select(time, signal, mac, oui, vendor,
		   type, length, tags, ssid, sequence) %>%
	mutate(time = as.POSIXct(time, format = "%b %d, %Y %H:%M:%OS"))


# ==============================================================================
# 01 Signal Strength
# ------------------------------------------------------------------------------
# Filter the data for signal strength greater than the given value. If value has 
# not been given, then classify the signal column into two using the given
# alogorithm and use the mid point as value. The algorithm default is 'kmeans'
# ==============================================================================

if(filter_signal_value %>% is.null()) {
	filter_signal_value <-
		classIntervals(data_00$signal, 2, filter_signal_algorithm)$brks[2]
}

data_01 <- 
	data_00 %>%
	filter(signal > filter_signal_value)

# ==============================================================================
# 02 Non Mobile Vendors
# ------------------------------------------------------------------------------
# Filter the data based on a the given vendor table. If no vendor table is given,
# then the step is skipped. If the vendor table doesn't exist then it is created
# with all true values for editing later 
# ==============================================================================

if(filter_vendor_table %>% is.null()) { 
	data_02 <- data_01
} else {

	if(!(filter_vendor_table %>% file.exists())) {
		generate_vendor_file(data_01$vendor, filter_vendor_table)}

	filter_vendor_table <-
		filter_vendor_table %>%
		read.csv(stringsAsFactors=FALSE)

	data_02 <-
		data_01 %>%
		inner_join(filter_vendor_table, by = "vendor") %>%
		filter(is_mobile == TRUE) %>%
		mutate(is_mobile = NULL)
}

# ==============================================================================
# 03 Unique Device Signature
# ------------------------------------------------------------------------------
# Determine a unique device signature (device_sign) based on the data available,
# For probes with global MACs they are considered as the device_sign. For public
# MACs, if the vendor is known, time compressed length sets are taken as the
# device_sign. Otherwise, time compressed sets of tags+ssid sets are taken as
# the device_sign
# ==============================================================================

subset_global <- data_02 %>% filter(type=="global")
subset_local  <- data_02 %>% filter(type=="local")

# ------------------------------------------------------------------------------
# After splitting the data into two parts - global and local mac addresses, we
# set the mac address as the unique identifier for global macaddresses
# we also identify and attach top 5 vendors as a variable for plotting later
# ------------------------------------------------------------------------------

top_vendors <-
	subset_global %>%
	group_by(vendor) %>%
	summarise(count = length(unique(mac))) %>%
	top_n(5,count) %>% pull(vendor)

subset_global <- 
	subset_global %>%
	mutate(device_sign = mac) %>%
	mutate(top_vendor = ifelse(vendor %in% top_vendors, vendor, "Other"))

# ------------------------------------------------------------------------------
# Here we compress the second part by time to produce tag and ssid sets to see
# If they are helpful in gettting us any answers.
# ------------------------------------------------------------------------------

subset_local_compressed <-
	subset_local %>%
	mutate(time = format(time,"%Y-%m-%d %H:%M:%OS")) %>%
	group_by(time, mac, oui, vendor, type) %>%
	summarise(signal = mean(signal),
			  length = paste(sort(unique(length)), collapse = "-"),
			  tags_set = paste(sort(unique(tags)), collapse = "-"),
			  ssid_set = paste(sort(unique(ssid)), collapse = "-"),
			  sequence_set = paste(sequence, collapse = ",")) %>%
	ungroup() %>%
	mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%OS"))

# ------------------------------------------------------------------------------
# Need to write about how length parameter is more than enough for Google
# ------------------------------------------------------------------------------

subset_local %>%
	ggplot() +
	geom_point(aes(time, sequence, col = as.character(length)),
			   show.legend = FALSE)

subset_local_compressed_google <-
	subset_local_compressed %>%
	filter(vendor == "Google")

subset_local_compressed_google %>%
	ggplot() +
	geom_point(aes(mac,tags_set),show.legend = FALSE)+
	scale_y_discrete(label=abbreviate)

# ------------------------------------------------------------------------------
# Need to write about how ssid paramter is pretty much useless.
# ------------------------------------------------------------------------------
subset_local_compressed %>%
	filter(vendor == "Unknown") %>%
	ggplot() +
	geom_point(aes(time,ssid_set), show.legend = FALSE) +
	theme(axis.text.y = element_blank())

# subset_local %>%
# 	filter(vendor != "Google",
# 		   time < as.POSIXct("20171220 123500",format="%Y%m%d %H%M%S")) %>%
# 	ggplot() +
# 	geom_point(aes(time,sequence,col=mac),show.legend=FALSE)

# fuzzy cmeans - no need for number of clusters with distance parameters
# filter out clusters
# linear regression 

# ==============================================================================
# Creating a series of plots of the data for communications
# ==============================================================================

# ------------------------------------------------------------------------------
# Methods used to plot data
# ------------------------------------------------------------------------------



# ------------------------------------------------------------------------------
# Plot objects
# ------------------------------------------------------------------------------

plot_all_time_seq <-
	data_02 %>%	
	ggplot() +
	geom_point(aes(time, sequence, col = mac), show.legend = FALSE)

plot_global_time_seq_all <-
	subset_global %>%	
	ggplot() +
	geom_point(aes(time, sequence, col = mac), show.legend = FALSE) +
	facet_grid(top_vendor~.)

plot_local_time_seq_all <-
	subset_local %>%
	ggplot() +
	geom_point(aes(time,sequence,col=mac),show.legend=FALSE) +
	facet_grid(vendor~.)

plot_global_time_seq_zoom <-
	subset_global %>%
	filter(time < as.POSIXct("20171220 123500",format="%Y%m%d %H%M%S")) %>%
	ggplot() +
	geom_point(aes(time, sequence, col = mac), show.legend = FALSE) +
	facet_grid(top_vendor~.)

plot_local_time_seq_zoom <-
	subset_local %>%
	filter(time < as.POSIXct("20171220 123500",format="%Y%m%d %H%M%S")) %>%
	ggplot() +
	geom_point(aes(time,sequence,col=mac),show.legend=FALSE) +
	facet_grid(vendor~.)

# ------------------------------------------------------------------------------
# Clean names for plotting on screen
# ------------------------------------------------------------------------------

plot_all_time_seq
plot_global_time_seq_all
plot_local_time_seq_all
plot_global_time_seq_zoom
plot_local_time_seq_zoom
