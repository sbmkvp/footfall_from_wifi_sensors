library(tidyverse)
library(ggplot2)
library(RPostgreSQL)
connection <- dbConnect(dbDriver('PostgreSQL'), dbname = 'bala_ijgis', user = 'bala_read', password = 'readpasswordbala', host = 'cdrc-footfall.geog.ucl.ac.uk')
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

sensor_schedule <- dbGetQuery(connection,"select date(timestamp), sensor from sensor where date(timestamp) < '2018-04-01' group by 1,2 order by 1,2;")
sensor_schedule$sensor <- factor(as.character(sensor_schedule$sensor),levels=c("88","66","55","44","33","22","11")) 
# ggplot(sensor_schedule[ sensor_schedule$sensor %in% c(11,22,33,44,55), ])+geom_tile(aes(date,sensor),color="white",size=5)+theme_void()
#
# ggplot(sensor_data)+geom_histogram(aes(-signal),fill="black")+facet_grid(sensor~.)+theme_void()
#
# sensor_data %>% 
# 	filter(-signal>25,type=="local") %>%
# 	ggplot() +
# 		geom_density(aes(-signal),fill="black") +
# 		facet_grid(sensor~.) +
# 		theme_light() +
# 		xlab("") +
# 		ylab("") +
# 		theme(panel.grid.major=element_blank(),
# 			  panel.grid.minor=element_blank(),
# 			  panel.border=element_blank(),
# 			  strip.text=element_blank(),
# 			  axis.title.x=element_blank(),
# 			  axis.text.x=element_blank(),
# 			  axis.ticks.x=element_blank(),
# 			  axis.title.y=element_blank(),
# 			  axis.text.y=element_blank(),
# 			  axis.ticks.y=element_blank())
#
sensor_data_filtered <- (function(){
	just_global <- sensor_data %>% filter(type=="global")
	just_local <- sensor_data %>% filter(type=="local")
	thres_11 <- (just_local %>% filter(signal<(-25),sensor==11) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	thres_22 <- (just_local %>% filter(sensor==22) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	thres_33 <- (just_local %>% filter(sensor==33) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	thres_44 <- (just_local %>% filter(sensor==44) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	thres_55 <- (just_local %>% filter(sensor==55) %>% pull(signal) %>% classIntervals(.,2,"kmeans"))$brks[2]
	local_11 <-  just_local %>% filter(signal>thres_11)
	local_22 <-  just_local %>% filter(signal>thres_22)
	local_33 <-  just_local %>% filter(signal>thres_33)
	local_44 <-  just_local %>% filter(signal>thres_44)
	local_55 <-  just_local %>% filter(signal>thres_55)
	return(rbind(just_global,local_11,local_22,local_33,local_44,local_55))
})()

is_moving <- function(x) { return( !(((x - (5 * 60)) %in% x) |
	((x - (01 * 60)) %in% x) |
	((x - (02 * 60)) %in% x) |
	((x - (03 * 60)) %in% x) |
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
	((x - (15 * 60)) %in% x) ) ) }

filter_moving <- function(x) {
	data_vector <- unlist(x[[1]])
	logical_vector <- unlist(x[[2]])
	return( data_vector[logical_vector] ) }

flatten_list <- function(x) {
	return( data.frame(mac = x[[1]],
		timestamp = x[[2]],
		stringsAsFactors = FALSE) ) }

get_counts <- function(s) {
	test_counts_filtered <- sensor_data_filtered %>%
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

	test_counts_raw <- sensor_data %>% 
		filter(sensor==s) %>% 
		mutate(timestamp = as.character(as.POSIXct(floor_date(timestamp,'1 minute')))) %>%
		group_by(timestamp) %>% 
		summarise(raw = mac %>% unique %>% length) %>%
		data.frame

	test_counts_manual <- manual_data %>%
		filter(sensor==s) %>% 
		mutate(timestamp = as.character(floor_date(timestamp,'1 minute'))) %>%
		group_by(timestamp, sensor) %>%
		summarise(manual = timestamp %>% length) %>%
		data.frame

	comparison <- list(test_counts_raw, test_counts_filtered, test_counts_manual) %>%
		reduce(left_join, by = "timestamp")
	comparison$sensor <- s
	return(comparison)
}

get_location_parameters <- (function(){
	counts11 <- get_counts(11)
	counts22 <- get_counts(22)
	counts33 <- get_counts(33)
	counts44 <- get_counts(44)
	counts55 <- get_counts(55)

})()

ggplot(comparison)+geom_line(aes(timestamp,raw,group="raw"),col="red")+geom_line(aes(timestamp,filtered,group="filtered"),col="green")+geom_line(aes(timestamp,manual,group="manual"))

dbDisconnect(connection)
