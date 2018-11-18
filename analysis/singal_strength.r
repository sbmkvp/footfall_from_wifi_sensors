rm(list = ls())

library(tidyverse)
library(classInt)
library(ggplot2)
library(igraph)
library(lubridate)

signal_comparision <- function(method,records) {
	print(method)
	t1 <- Sys.time()
	sensor <- "../data/final_sensor_data.csv" %>% 
		read.csv(stringsAsFactors = FALSE) %>% as_tibble() %>%
		select(time, signal, mac, oui, vendor, type, sequence) %>%
		mutate(time = as.POSIXct(time, format = "%b %d, %Y %H:%M:%OS")) %>%
		arrange(time) %>% head(records)
	llogg <- capture.output({threshold <- classIntervals(sensor$signal, 2, method)$brks[2]})
	print(threshold)
	add_signature <- function(data, ds, dt) {
		vertices <- data %>%
			mutate(x = as.integer(time), id = as.numeric(rownames(data))) %>%
			select(id, x, y=sequence) %>%
			arrange(x)
		edges <- vertices %>%
			pull(id) %>% expand.grid(.,.) %>% rename(from=Var1,to=Var2) %>%
			mutate(from=as.numeric(from), to=as.numeric(to)) %>%
			filter(from<to) %>%
			left_join(vertices, by = c("from" = "id")) %>%
			left_join(vertices, by = c("to" = "id")) %>%
			mutate(sdis = sqrt((y.y-y.x)**2)) %>%
			mutate(tdis = sqrt((x.y-x.x)**2)) %>%
			filter(x.y >= x.x, y.y > y.x, tdis < dt, sdis < ds) %>%
			group_by(from) %>% summarise(to = to[which(tdis == min(tdis))][[1]], tdis = min(tdis)) %>% 
			group_by(to) %>% summarise(from = from[which(tdis == min(tdis))][[1]])
		graph <- graph_from_data_frame(edges, vertices = vertices)
		data$device_sign <- paste(data$vendor, clusters(graph)$membership, sep = "-")
		return(data) }
	sensor <- sensor  %>% filter(signal > threshold) %>% 
		inner_join(read.csv("../data/final_vendors_data.csv", stringsAsFactors=FALSE), by = "vendor") %>%
		filter(is_mobile == TRUE) %>% mutate(is_mobile = NULL)
	subset_global <- sensor %>% filter(type == "global") %>% mutate(device_sign = mac)
	subset_local  <- sensor %>% filter(type == "local") %>% split(f = {.$vendor}) %>%
		lapply(add_signature, ds = 61, dt = 16) %>% bind_rows()
	sensor <- bind_rows(subset_global,subset_local) %>% 
		mutate(time = floor_date(time, "1 minute")) %>%
		group_by(device_sign) %>% summarise(time = min(time))
	sensor_counts <- sensor %>% group_by(time) %>% summarise(footfall = length(unique(device_sign))) %>%
		mutate(type="sensor")
	manual_counts <- "../data/oxst_manual.csv" %>% read.csv(stringsAsFactors=FALSE)%>%
		mutate(time = as.POSIXct(time)) %>%
		mutate(time = floor_date(time, "1 minute")) %>%
		group_by(time) %>% summarise(footfall = sum(count)) %>%
		mutate(type="manual")
    mape <- merge(manual_counts,sensor_counts,by="time") %>% 
		filter(time > "2017-12-20 12:29:00" & time < "2017-12-20 13:01:00") %>%
		mutate(diff = (footfall.y - footfall.x)/ footfall.x) %>%
		pull(diff) %>% mean
	mape <- (mape * 100) %>% round %>% as.character %>% paste("%")
	time <- as.numeric(Sys.time()-t1)
	print(mape); print(time); cat("\n\n");
	return(list(manual_counts = manual_counts,
				sensor_counts = sensor_counts,
				threshold = threshold,
				mape = mape,
				time = time))
}
methods <- c( "sd", "equal", "pretty", "quantile", "kmeans", "hclust", "bclust", "fisher")
for(i in methods) { 
	data <- signal_comparision(i,30000) }
