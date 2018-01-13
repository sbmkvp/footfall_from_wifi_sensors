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

if(filter_vendor_table %>% is.null()) { data_02 <- data_01 } else {

	if(!(filter_vendor_table %>% file.exists())) {
		generate_vendor_file(data_01$vendor, filter_vendor_table)
	}

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

subset_global <- 
	data_02 %>%
	filter(type=="global") %>%
	mutate(device_sign = paste0("mac_",mac))

subset_local <-
	data_02 %>%
	filter(type == "local") 

subset_local_time_compressed <-
	subset_local %>%
	mutate(time = format(time,"%Y-%m-%d %H:%M:%OS")) %>%
	group_by(time, mac, oui, vendor, type) %>%
	summarise(signal = mean(signal),
			  length = paste(sort(unique(length)),collapse="-"),
			  tags = paste(sort(unique(tags)),collapse="-"),
			  ssid = paste(sort(unique(ssid)),collapse="-"),
			  sequence = paste(sequence,collapse=",")) %>%
	ungroup() %>%
	mutate(time = as.POSIXct(time, format = "%Y-%m-%d %H:%M:%OS"))
