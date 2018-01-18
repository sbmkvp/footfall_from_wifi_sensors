# ==============================================================================
# Setup the environment
# ==============================================================================

rm(list = ls())
options(width = as.integer(Sys.getenv("COLUMNS")))

# ==============================================================================
# Load required libraries and submodules
# ==============================================================================

library(tidyverse) #for pipes and df oeprations
library(classInt) #for class intervals
library(ggplot2) #for plotting data
library(ggmap) #for plotting data
library(igraph) #for graph analysis
library(lubridate) #for date-time operations

# ==============================================================================
# Global variables
# ==============================================================================

sensor_file <- "../data/final_sensor_data.csv" #File with sensor collected data
manual_file <- "../data/final_manual_data.csv" #File with manual counting data
filter_signal_value <- NULL #Fill in if known. Best to leave NULL
filter_signal_algorithm <- "kmeans" #See classIntervals() for mroe options
filter_vendor_table <- "../data/final_vendors_data.csv" #Vendor list file
signature_sequence <- 60 #Threshold on the sequence for device signature
signature_time <- 16 #Threshold on time axis for device signature
interval <- "1 minute" #The aggregation interval. See lubridate:: for more info.

# ==============================================================================
# Read the data sensor_file and do basic formatting for legible display. Time is
# changed into an R compatible format.
# ==============================================================================

data_00 <- sensor_file %>%
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
# To-Do: Difference between 'kmeans' and other methodology.
# ==============================================================================

if(filter_signal_value %>% is.null()) {
	filter_signal_value <-
		classIntervals(data_00$signal, 2, filter_signal_algorithm)$brks[2]
}

data_01 <- data_00 %>% filter(signal > filter_signal_value)
data_00 <- data_00 %>% mutate(sig = signal > filter_signal_value)

# ==============================================================================
# 02 Non Mobile Vendors
# ------------------------------------------------------------------------------
# Filter the data based on a the given vendor table. If no vendor table is given,
# then the step is skipped. If the vendor table doesn't exist then it is created
# with all true values for editing later 
# ==============================================================================

# ------------------------------------------------------------------------------
# This function generates a csv file of the name specified from the given vector.
# Unique vendors are extracted and sorted alphabatically with all of them being
# marked as mobile vendors
# ------------------------------------------------------------------------------

generate_vendor_file <- function(vendor,location) {
	vendor %>%
		unique %>%
		sort %>%
		data.frame(vendor = ., is_mobile = rep(TRUE, length(.))) %>%
		write.csv(location, row.names = FALSE)
}

if(filter_vendor_table %>% is.null()) { 
	data_02 <- data_01
} else {

	if(!(filter_vendor_table %>% file.exists())) {
		generate_vendor_file(data_01$vendor, filter_vendor_table)}

	filter_vendor_table <-
		filter_vendor_table %>%
		read.csv(stringsAsFactors=FALSE)

	data_02 <- data_01 %>%
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

# ------------------------------------------------------------------------------
# For probe requests with global managed addresses, we assign the mac addresses
# as the unique identifier for global macaddresses
# ------------------------------------------------------------------------------

subset_global <- data_02 %>% 
	filter(type == "global") %>%
	mutate(device_sign = mac)

# ------------------------------------------------------------------------------
# For local mac addresses sequence numbers are the most relieable measure.
# We split the local mac addresses according to their vendor information.
# Add a device signatures and join them up again.
# ------------------------------------------------------------------------------
# We use a graph based clustering algorithm to detect clusters within the data
# and uniquely name them to be used as device signatures. First we make the 
# vertice ids from the row numbers of the probe requests. we populate a complete
# grid for all the points vs all other points. We remove the lower traingle so 
# that the graph is one directional ie always from lower id (which corresponds 
# to the time) to higher id. We calculate the sequence distance and time 
# distance between the point pairs and filter based on them as well. Finally we
# for each node with more than 1 incoming or out going link, We summarise the
# links to the one with the least distance.
# ------------------------------------------------------------------------------

add_signature <- function(data, ds, dt) {
	vertices <- data %>%
		mutate(x = as.integer(time), id = as.numeric(rownames(data))) %>%
		select(id, x, y=sequence) %>%
		arrange(x)
	edges <- vertices %>%
		pull(id) %>%
		expand.grid(.,.) %>% rename(from=Var1,to=Var2) %>%
		mutate(from=as.numeric(from), to=as.numeric(to)) %>%
		filter(from<to) %>%
		left_join(vertices, by = c("from" = "id")) %>%
		left_join(vertices, by = c("to" = "id")) %>%
		mutate(sdistance = sqrt((y.y-y.x)**2)) %>%
		mutate(tdistance = sqrt((x.y-x.x)**2)) %>%
		filter(x.y >= x.x, y.y > y.x, tdistance < dt, sdistance < ds) %>%
		group_by(from) %>%
		summarise(to = to[which(tdistance == min(tdistance))][[1]],
				  tdistance = min(tdistance)) %>% 
		group_by(to) %>%
		summarise(from = from[which(tdistance == min(tdistance))][[1]])
	graph <- graph_from_data_frame(edges, vertices = vertices)
	data$device_sign <- paste(data$vendor, clusters(graph)$membership, sep = "-")
	data
}

# ------------------------------------------------------------------------------
# We apply the function over each vendor in public range iteratively and join
# them together. Finally we bind both global and local probes together as they
# have a unique id to be worked with.
# To-do: split the table based on length as well for better clustering.
# ------------------------------------------------------------------------------
subset_local  <- data_02 %>%
	filter(type == "local") %>%
	split(f = {.$vendor}) %>%
	lapply(add_signature,ds = signature_sequence,dt=signature_time) %>%
	bind_rows()

data_03 <- bind_rows(subset_global,subset_local)

# ==============================================================================
# 04 # Removing Long Dwellers
# ------------------------------------------------------------------------------
# Here we set the time interval by rounding the time to the previous interval
# based on the global variable and remove all but the first occurrance of the 
# the device_signature.
# ==============================================================================

data_04 <- data_03 %>%
	mutate(time = floor_date(time, interval)) %>%
	group_by(device_sign) %>%
	summarise(time = min(time))

# ==============================================================================
# 05 # Counting unique devices at each stage
# ------------------------------------------------------------------------------
# Here we count the unique devices at each stage based on the time and unique id
# that was present at that stage.
# ==============================================================================
count_data_00 <- data_00 %>%
	mutate(time = floor_date(time, interval)) %>%
	group_by(mac) %>%
	summarise(time = min(time)) %>% 
	mutate(time = floor_date(time, interval)) %>%
	group_by(time) %>% summarise(footfall = length(unique(mac))) %>%
	mutate(type = "00 No filtering")

count_data_01 <- data_01 %>% mutate(time = floor_date(time, interval)) %>%
	group_by(time) %>% summarise(footfall = length(unique(mac))) %>%
	mutate(type = "01 Filtered out low signal strength")

count_data_02 <- data_02 %>% mutate(time = floor_date(time, interval)) %>%
	group_by(time) %>% summarise(footfall = length(unique(mac))) %>%
	mutate(type = "02 Filter out non-mobile vendors")

count_data_03 <- data_03 %>% mutate(time = floor_date(time, interval)) %>%
	group_by(time) %>% summarise(footfall = length(unique(device_sign))) %>%
	mutate(type = "03 Filter out randomised MACs")

count_data_04 <- data_04 %>%
	group_by(time) %>% summarise(footfall = length(unique(device_sign))) %>%
	mutate(type = "04 Filter out long dwelling devices")

count_data_05 <- "../data/oxst_manual.csv" %>%
	read.csv(stringsAsFactors=FALSE)%>%
	mutate(time = as.POSIXct(time)) %>%
	mutate(time = floor_date(time, interval)) %>%
	group_by(time) %>% summarise(footfall = sum(count)) %>%
	mutate(type = "05 Manual counting")

count_all <- bind_rows(count_data_01, count_data_02, 
					   count_data_03, count_data_04, count_data_05)

# ==============================================================================
# Cleaning up stuff
# ==============================================================================

rm(sensor_file,
   filter_signal_value,
   filter_signal_algorithm,
   filter_vendor_table,
   signature_sequence,
   signature_time,
   generate_vendor_file,
   add_signature)
