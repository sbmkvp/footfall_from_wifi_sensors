library(ggplot2)
library(reshape2)
library(tidyverse)
library(classInt)
library(digest)
library(xts)
library(magrittr)

read_file <- function(location) {
	location %>%
		read.csv(.,stringsAsFactors=FALSE) %>%
		as_tibble() %>%
		mutate(id = NULL,
			   time = as.POSIXct(time)) %>%
		return
}

filter_by_signal <- function(data,limit=NULL) {
	data %>%
		filter(signal > ifelse(is.null(limit),
							   classIntervals(signal, 2, "kmeans")$brks[2],
							   limit)) %>%
	return
}

set_interval <- function(data,mins) {
	data %>%
		mutate(time = align.time(time,mins*60)) %>%
		return
}

remove_repeat_devices <- function(data,by) {
	data %>%
		group_by(get(by)) %>%
		summarise(time = min(time)) %>%
		rename_at("get(by)",function(.){ by }) %>% 
		return
}

count_by <- function(data, column, by, label=NULL) {
	data %>%
		group_by(get(by)) %>%
		summarise(value = length(get(column))) %>%
		rename_at("get(by)",function(.){ by }) %>% 
		rename_at("value",function(.){
			   ifelse(is.null(label),column,label)
			   }) %>% 
		return
}

prepare_with <- function(data,
						 interval,
						 column_count,
						 step) {
	data %>%
		set_interval(interval) %>%
		count_by(column_count,"time","footfall") %>%
		mutate(action = step) %>%
		return
}

identify_unique_devices <- function(data) {
	data %>%
		return
}
