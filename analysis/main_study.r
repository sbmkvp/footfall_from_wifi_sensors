library(tidyverse)
library(ggplot2)
library(RPostgreSQL)
library(igraph)
library(classInt)
library(lubridate)

## Doesn't work anymore has to be changed to read settings through the config file ---------
connection <- dbConnect(dbDriver('PostgreSQL'), dbname = 'bala_ijgis', user = 'bala_read', password = 'balareadpassword', host = 'cdrc-footfall.geog.ucl.ac.uk')
--------------------------------------------------------------------------------------------
manual_schedule <- dbGetQuery(connection,"select new_sensor as sensor, min(date_trunc('minute',timestamp::timestamp)+interval '1 minute') as start, max(date_trunc('minute',timestamp::timestamp)) as end from manual left join locations on locations.id = manual.location group by date(timestamp),new_sensor order by 1;")
if(!exists("sensor_data")){ 
	sensor_data <- (function(){
		data <- dbGetQuery(connection,"select * from sensor limit 0;")
		for(i in 1:nrow(manual_schedule)) {
			addition <- dbGetQuery(connection,paste0("select sensor.*, vendor.vendor,case when substring(sensor.oui,2,1) in ('e','a','2','6') then 'local' else 'global' end as type from sensor left join vendor on sensor.oui=vendor.oui where sensor = '",manual_schedule$sensor[i],"' and timestamp between '",manual_schedule$start[i],"' and '",manual_schedule$end[i],"';"))
			data <- rbind(data,addition) 
		}
		return(data)
	})()
}
if(!exists("manual_data")){ 
	manual_data <- (function(){
		data <- dbGetQuery(connection,"select * from manual limit 0;")
		for(i in 1:nrow(manual_schedule)) {
			addition <- dbGetQuery(connection,paste0("select timestamp, new_sensor as sensor from manual left join locations on locations.id = manual.location where new_sensor = '",manual_schedule$sensor[i],"' and timestamp between '",manual_schedule$start[i],"' and '",manual_schedule$end[i],"';"))
			data <- rbind(data,addition) 
		}
		return(data)
	})()
}

if(!exists("sensor_schedule")){ 
	sensor_schedule <- dbGetQuery(connection,"select date(timestamp), sensor from sensor where date(timestamp) < '2018-04-01' group by 1,2 order by 1,2;")
	sensor_schedule$sensor <- factor(as.character(sensor_schedule$sensor),levels=c("88","66","55","44","33","22","11")) 
}

schedule_plot <- ggplot(sensor_schedule[ sensor_schedule$sensor %in% c(11,22,33,44,55), ])+geom_tile(aes(date,sensor),color="white",size=5)+theme_void()

test_signal <- ggplot(sensor_data)+geom_histogram(aes(-signal),fill="black")+facet_grid(sensor~.)+theme_void()

singal_plot <- sensor_data %>% 
	filter(-signal>25,type=="local") %>%
	ggplot() +
		geom_density(aes(-signal),fill="black") +
		facet_grid(sensor~.) +
		theme_light() +
		xlab("") +
		ylab("") +
		theme(panel.grid.major=element_blank(),
			  panel.grid.minor=element_blank(),
			  panel.border=element_blank(),
			  strip.text=element_blank(),
			  axis.title.x=element_blank(),
			  axis.text.x=element_blank(),
			  axis.ticks.x=element_blank(),
			  axis.title.y=element_blank(),
			  axis.text.y=element_blank(),
			  axis.ticks.y=element_blank())

get_sensor_data_filtered <- function(data){
	just_global <- data %>% filter(type=="global")
	just_local <- data %>% filter(type=="local")
	thres_11 <- (just_local %>% filter(sensor==11) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	thres_22 <- (just_local %>% filter(sensor==22) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	thres_33 <- (just_local %>% filter(sensor==33) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	thres_44 <- (just_local %>% filter(sensor==44) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	thres_55 <- (just_local %>% filter(sensor==55) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	local_11 <-  just_local %>% filter(sensor==11) %>% filter(signal>thres_11)
	local_22 <-  just_local %>% filter(sensor==22) %>% filter(signal>thres_22)
	local_33 <-  just_local %>% filter(sensor==33) %>% filter(signal>thres_33)
	local_44 <-  just_local %>% filter(sensor==44) %>% filter(signal>thres_44)
	local_55 <-  just_local %>% filter(sensor==55) %>% filter(signal>thres_55)
	print(paste(thres_11,thres_22,thres_33,thres_44,thres_55))
	return(rbind(just_global,local_11,local_22,local_33,local_44,local_55))
}
sensor_data_filtered <- get_sensor_data_filtered(sensor_data)

get_sensor_data_clustered <- function(data_filtered) {
	add_signature <- function(data, ds=200, dt=60) {
		vertices <- data %>%
			mutate(x = as.integer(timestamp), id = as.numeric(rownames(data))) %>%
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
			mutate(distance = sqrt((tdistance**2)+(sdistance**2))) %>%
			filter(x.y >= x.x, y.y > y.x, tdistance < dt, sdistance < ds) %>%
			group_by(from) %>%
			summarise(to = to[which(distance == min(distance))][[1]],
					  distance = min(distance)) %>% 
			group_by(to) %>%
			summarise(from = from[which(distance == min(distance))][[1]])
		graph <- graph_from_data_frame(edges, vertices = vertices)
		data$signature <- paste(data$vendor,data$date,data$sensor,clusters(graph)$membership, sep = "-")
		data
	}
	just_global <- data_filtered %>% 
		filter(type == "global") %>% 
		mutate(date = as.Date(timestamp))
	just_global$signature <- paste("global",just_global$date,just_global$mac,sep="-")
	just_local <- data_filtered %>% 
		filter(type == "local") %>%
		mutate(date = as.Date(timestamp)) %>% 
		mutate(vendor = replace(vendor,is.na(vendor),"unknown")) %>% 
		split(f = list(.$sensor,.$date,.$vendor)) %>%
		lapply(add_signature) %>%
		bind_rows()
	 return(bind_rows(just_local,just_global))
}
sensor_data_clustered <- get_sensor_data_clustered(sensor_data_filtered)

get_counts <- function(data,data_manual,data_filtered,data_clustered,s) {
	is_moving <- function(x) { return( !(((x - (5 * 60)) %in% x) |
		((x - (01 * 60)) %in% x) |
		((x - (02 * 60)) %in% x) |
		((x - (03 * 60)) %in% x) |
		((x - (04 * 60)) %in% x) |
		((x - (05 * 60)) %in% x) |
		((x - (06 * 60)) %in% x) |
		((x - (07 * 60)) %in% x) |
		((x - (08 * 60)) %in% x) |
		((x - (09 * 60)) %in% x) |
		((x - (10 * 60)) %in% x) |
		((x - (11 * 60)) %in% x) |
		((x - (12 * 60)) %in% x) |
		((x - (13 * 60)) %in% x) |
		((x - (14 * 60)) %in% x) |
		((x - (15 * 60)) %in% x) |
		((x - (16 * 60)) %in% x) |
		((x - (17 * 60)) %in% x) |
		((x - (18 * 60)) %in% x) |
		((x - (19 * 60)) %in% x) |
		((x - (10 * 60)) %in% x) |
		((x - (21 * 60)) %in% x) |
		((x - (22 * 60)) %in% x) |
		((x - (23 * 60)) %in% x) |
		((x - (24 * 60)) %in% x) |
		((x - (25 * 60)) %in% x) |
		((x - (26 * 60)) %in% x) |
		((x - (27 * 60)) %in% x) |
		((x - (28 * 60)) %in% x) |
		((x - (29 * 60)) %in% x) |
		((x - (30 * 60)) %in% x) |
		((x - (31 * 60)) %in% x) |
		((x - (32 * 60)) %in% x) |
		((x - (33 * 60)) %in% x) |
		((x - (34 * 60)) %in% x) |
		((x - (35 * 60)) %in% x) |
		((x - (36 * 60)) %in% x) |
		((x - (37 * 60)) %in% x) |
		((x - (38 * 60)) %in% x) |
		((x - (39 * 60)) %in% x) |
		((x - (40 * 60)) %in% x) |
		((x - (41 * 60)) %in% x) |
		((x - (42 * 60)) %in% x) |
		((x - (43 * 60)) %in% x) |
		((x - (44 * 60)) %in% x) |
		((x - (45 * 60)) %in% x) |
		((x - (46 * 60)) %in% x) |
		((x - (47 * 60)) %in% x) |
		((x - (48 * 60)) %in% x) |
		((x - (49 * 60)) %in% x) |
		((x - (50 * 60)) %in% x) |
		((x - (51 * 60)) %in% x) |
		((x - (52 * 60)) %in% x) |
		((x - (53 * 60)) %in% x) |
		((x - (54 * 60)) %in% x) |
		((x - (55 * 60)) %in% x) |
		((x - (56 * 60)) %in% x) |
		((x - (57 * 60)) %in% x) |
		((x - (58 * 60)) %in% x) |
		((x - (59 * 60)) %in% x) |
		((x - (60 * 60)) %in% x) ) ) }
	filter_moving <- function(x) {
		data_vector <- unlist(x[[1]])
		logical_vector <- unlist(x[[2]])
		return( data_vector[logical_vector] ) }
	flatten_list <- function(x) {
		return( data.frame(mac = x[[1]],
			timestamp = x[[2]],
			stringsAsFactors = FALSE) ) }
	flatten_list_cluster <- function(x) {
		return( data.frame(signature = x[[1]],
		timestamp = x[[2]],
		stringsAsFactors = FALSE) ) }

	test_counts_clustered <- data_clustered %>%
		mutate(timestamp = as.POSIXct(floor_date(timestamp,'1 minute'))) %>%
		group_by(signature) %>%
		summarize(timestamps = timestamp %>% list) %>% 
		mutate(is_moving = lapply(timestamps, is_moving)) %>%
		mutate(timestamps = apply(.[ ,c(2, 3)], 1, filter_moving)) %>%
		select(-is_moving) %>%
		apply(1, flatten_list_cluster) %>%
		do.call("rbind", .) %>%
		mutate(timestamp = as.character(timestamp)) %>%
		group_by(timestamp) %>% 
		summarize(clustered = signature %>% unique %>% length) %>%
		data.frame

	test_counts_filtered <- data_filtered %>%
		filter(sensor==s) %>% 
		mutate(timestamp = as.POSIXct(floor_date(timestamp,'1 minute'))) %>%
		group_by(mac) %>%
		summarize(timestamps = timestamp %>% list) %>% 
		mutate(is_moving = lapply(timestamps, is_moving)) %>%
		mutate(timestamps = apply(.[ ,c(2, 3)], 1, filter_moving)) %>%
		select(-is_moving) %>%
		apply(1, flatten_list) %>%
		do.call("rbind", .) %>%
		mutate(timestamp = as.character(timestamp)) %>%
		group_by(timestamp) %>% 
		summarize(filtered = mac %>% unique %>% length) %>%
		data.frame

	test_counts_raw <- data %>% 
		filter(sensor==s) %>% 
		mutate(timestamp = as.character(as.POSIXct(floor_date(timestamp,'1 minute')))) %>%
		group_by(timestamp) %>% 
		summarise(raw = mac %>% unique %>% length) %>%
		data.frame

	test_counts_manual <- data_manual %>%
		filter(sensor==s) %>% 
		mutate(timestamp = as.character(floor_date(timestamp,'1 minute'))) %>%
		group_by(timestamp, sensor) %>%
		summarise(manual = timestamp %>% length) %>%
		data.frame

	
	comparison <- list(test_counts_raw, test_counts_filtered, test_counts_clustered, test_counts_manual) %>%
		reduce(left_join, by = "timestamp")
	comparison$sensor <- s
	return(comparison)
}

get_location_parameters <- function(){
	counts_df <- data.frame()
	data <- data.frame()
	for(i in c(11,22,33,44,55)) {
		counts <- get_counts(sensor_data,manual_data,sensor_data_filtered,sensor_data_clustered,i)
		counts <- counts[2:(nrow(counts)-1),]
		if(i == 11) { counts <- counts %>% filter(as.Date(timestamp)!="2018-02-21") }
		counts[is.na(counts)] <- 1
		counts[counts==0] <- 1
		
		counts$adj_factor <- mean(counts$manual/counts$clustered)
		counts$adjusted <- counts$clustered*counts$adj_factor

		counts_gather <- counts
		counts_gather$sensor <- NULL
		counts_gather <- gather(counts,"type","count",-timestamp)
		counts_gather$sensor <- i
		counts_df <- rbind(counts_df,counts_gather)
		
		mape1 <- mean((counts$raw - counts$manual)/counts$manual)*100
		mape2 <- mean((counts$filtered - counts$manual)/counts$manual)*100
		mape3 <- mean((counts$clustered - counts$manual)/counts$manual)*100
		mape4 <- mean((counts$adjusted - counts$manual)/counts$manual)*100
		data <- rbind(data, data.frame(sensor = i,
									   mape_raw = mape1,
									   mape_sig = mape2,
									   mape_clu = mape3,
									   mape_adj = mape4))
		cat(".")
	}
	cat("\n")
	return(list(data,counts_df))
}

results <- get_location_parameters()
locations_table <- results[[1]]
counts <- results[[2]]

counts_plot <- counts %>%
	filter(type != "sensor",type != "adj_factor") %>%
	split(list(.$sensor)) %>%
	lapply(function(x){
	   if(nrow(x)>0){
		   ints <- data.frame(timestamp = unique(x$timestamp), interval = 1:length(unique(x$timestamp)));
		   x <- merge(x, ints, by = "timestamp");
		   return(x) }}) %>% 
	bind_rows() %>%
	ggplot() + 
		geom_line(aes(interval, count, group = type,col=type),size=0.3,show.legend = FALSE) +
		geom_point(aes(interval, count,shape = type,col=type),size=0.8) +
		facet_grid(sensor~.) +
		theme(panel.background = element_blank(),
			  panel.border = element_rect(color = "grey", fill = "#00000000"),
			  strip.text = element_blank(),
			  axis.text.x = element_blank(),
			  axis.text.y = element_blank(),
			  legend.position = "bottom") +
		xlab("") +
		ylab("") +
		scale_color_manual(values=c("#e41a1c","#377eb8","#ff7f00","#4daf4a","#333333"))

dbDisconnect(connection)

single_sensor <- dbGetQuery(connection,"select sensor.*, vendor.vendor,case when substring(sensor.oui,2,1) in ('e','a','2','6') then 'local' else 'global' end as type from sensor left join vendor on sensor.oui=vendor.oui where sensor = 55 and date(timestamp) > '2018-02-18' and date(timestamp) < '2018-02-26';")

single_sensor_c <- single_sensor %>%
	mutate(date = as.Date(timestamp),
		   hour = format(timestamp,"%H"),
		   five = format(floor_date(timestamp,"5 minutes"),"%M")) %>%
	select(-sensor,-length,-oui) %>%
	mutate(interval = paste(date,hour,five,sep="-"))

filter_signal <- function(d) {
	if(nrow(d)>0) {
		sig <- d$sig[d$type=="local"]
		thres <- classIntervals(sig,2,"kmeans")$brks[2]
		return(d[!(d$type=="local" & d$signal<thres),])
	}
}

filter_sequence <- function(data, ds=200, dt=60) {
	if(nrow(data)>0) {
	data1 <- data[data$type=="global",]
	data1$signature <- paste(data1$date,data1$mac,sep="-")
	data <- data[data$type=="local",]
	vertices <- data %>%
		mutate(x = as.integer(timestamp), id = as.numeric(rownames(data))) %>%
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
		mutate(distance = sqrt((tdistance**2)+(sdistance**2))) %>%
		filter(x.y >= x.x, y.y > y.x, tdistance < dt, sdistance < ds) %>%
		group_by(from) %>%
		summarise(to = to[which(distance == min(distance))][[1]],
				  distance = min(distance)) %>% 
		group_by(to) %>%
		summarise(from = from[which(distance == min(distance))][[1]])
	graph <- graph_from_data_frame(edges, vertices = vertices)
	data$signature <- paste(data$vendor,data$date,data$hour,clusters(graph)$membership, sep = "-")
	return (rbind(data1,data))
	}
}

single_sensor_filtered <- single_sensor_c %>% 
	split(f=list(.$date,.$hour)) %>%
	lapply(filter_signal) %>% bind_rows()

single_sensor_clustered <- single_sensor_filtered %>% split(f=list(.$vendor,.$date,.$hour)) %>% lapply(filter_sequence) %>% bind_rows()

single_counts <- single_sensor_clustered %>% group_by(interval) %>% summarise(count = signature %>% unique %>% length)

single_counts$count_prev <- append(c(0),single_counts$count[(1:nrow(single_counts)-1)])
single_counts$count_next <- append(single_counts$count[2:nrow(single_counts)],c(0))
single_counts$count <- ifelse(single_counts$count < 10, (single_counts$count_prev+single_counts$count_next)/2, single_counts$count)

ggplot(single_counts) + 
	geom_line(aes(interval,count,group=""),
			  stat="identity",
			  color="black",
			  size = 0.3) +
	theme_light()
	# xlab("") +
	# ylab("") +
	theme(panel.grid.major=element_blank(),
		  panel.grid.minor=element_blank(),
		  panel.border=element_blank(),
		  strip.text=element_blank(),
		  axis.title.x=element_blank(),
		  axis.text.x=element_blank(),
		  axis.ticks.x=element_blank(),
		  axis.title.y=element_blank(),
		  axis.text.y=element_blank(),
		  axis.ticks.y=element_blank())

