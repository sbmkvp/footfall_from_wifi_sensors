rm(list=ls())
library(tidyverse)
library(magrittr)
library(networkD3)

ucl_data <- read.csv("../data/ucl_sensor.csv",stringsAsFactors=FALSE)
oxst_data <- read.csv("../data/oxst_sensor.csv",stringsAsFactors=FALSE)

oxst_data %<>%
	as_tibble() %>%
	select(type,vendor,length,mac) 
#	filter(vendor %in% c("Unknown",
#						 "Google",
#						 "CompexPt",
#						 "Apple",
#						 "Motorola",
#						 "SamsungE"))

make_links <- function(data,source,target) {
	data %>%
		select(source = source,
			   target = target,
			   mac) %>%
		mutate(source = as.character(source),
			   target = as.character(target)) %>%
		group_by(source,target) %>%
		summarise(value=length(unique(mac))) %>%
		return}

oxst_nodes <- data.frame(
						 name = unique(c(
										 #oxst_data$length,
										 oxst_data$type,
										 oxst_data$vendor)),stringsAsFactors = FALSE)
oxst_nodes$id <- as.numeric(row.names(oxst_nodes))-1
oxst_links <-
	bind_rows(
			 oxst_data %>% make_links("type","vendor"),
			 #oxst_data %>% make_links("vendor","length")
			 ) %>%
	left_join(oxst_nodes,by=c("source"="name")) %>%
	left_join(oxst_nodes,by=c("target"="name")) %>%
	data.frame()

sankeyNetwork(oxst_links,oxst_nodes,"id.x","id.y","value",NodeID="name")

