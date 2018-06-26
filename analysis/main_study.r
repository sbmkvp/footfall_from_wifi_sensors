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
ggplot(sensor_schedule[ sensor_schedule$sensor %in% c(11,22,33,44,55), ])+geom_tile(aes(date,sensor),color="white",size=5)+theme_void()

ggplot(sensor_data)+geom_histogram(aes(-signal),fill="black")+facet_grid(sensor~.)+theme_void()

sensor_data %>% 
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


dbDisconnect(connection)
