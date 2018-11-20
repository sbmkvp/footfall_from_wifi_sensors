library(tidyverse); library(classInt); library(ggplot2); library(igraph); library(lubridate)

get_clustered <- function(thres_s,thres_t) {
	sensor <- "../data/final_sensor_data.csv" %>% 
		read.csv(stringsAsFactors = FALSE) %>% as_tibble() %>%
		select(time, signal, mac, oui, vendor, type, sequence) %>%
		mutate(time = as.POSIXct(time, format = "%b %d, %Y %H:%M:%OS"))
	threshold <- classIntervals(sensor$signal, 2, "kmeans")$brks[2]
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
		filter(is_mobile == TRUE) %>% mutate(is_mobile = NULL) %>%
		filter(type == "local") %>% split(f = {.$vendor}) %>%
		lapply(add_signature, ds = thres_s, dt = thres_t) %>% bind_rows()
	return(sensor) }

get_df <- function(range_x,range_y) { 
	data <- data.frame(); 
	for(i in range_x) { 
		for (j in range_y) { 
			temp <- get_clustered(i,j) %>% data.frame(); 
			temp$i <- i; temp$j <- j; 
			data <- bind_rows(data,temp); }}
	return(data); }

# data <- get_df(c(50,60,70), c(15,16,17))

plot_d <- function(d) {
	return( d %>% 
		ggplot() +
		geom_line(aes(time, sequence, group = device_sign)) +
		facet_wrap(j~i,nrow=1,ncol=6) + 
		theme_minimal() + 
		theme(strip.text = element_blank(),
			  axis.text = element_blank(),
			  axis.title = element_blank()) ) }
