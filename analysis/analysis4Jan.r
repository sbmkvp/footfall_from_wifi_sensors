clean_sensor_data <- function(input,output) {
	library(digest)
	data <- read.csv(input,header=FALSE,stringsAsFactors=FALSE)
	names(data) <- c("time","length","signal","duration","vendor","macaddress","sequence","tags","ssid")
	data$time <- as.POSIXct(data$time,format="%b %d, %Y %H:%M:%OS")
	data$type <- ifelse(substr(data$macaddress,2,2)%in%c('2','6','e','a'),"local","global")
	data$mac <- sapply(data$macaddress,digest,algo="sha1")
	data$oui  <- substr(data$macaddress,1,8)
	data$macaddress <- NULL
	data$vendor <- sapply(
		strsplit(as.character(data$vendor),split="_"),
		function(d){
			if (length(d)==2) { d[1] } else { "Unknown" }
		}
	) 
	write.csv(data,output)
	print(paste("Cleaned file saved at", output))
}

analyse_data <- function(manual = NULL, sensor = NULL, interval = 5) {
	source("methods.r")
	if(!is.null(manual)) {
		manual <- manual %>% read_file()
		manual %<>% prepare_with(interval, "count", "Manual counts")
	}
	if(!is.null(sensor)) {
		sensor <- sensor %>% read_file()
		sensor_range <- sensor %>% filter_by_signal()
		sensor_unique <- sensor_range %>% identify_unique_devices()
		sensor_repeat <- sensor_unique %>% remove_repeat_devices("mac")
		sensor %<>% prepare_with(interval, "mac", "Probe requests")
		sensor_range %<>% prepare_with(interval, "mac", "Within range")
		sensor_unique %<>% prepare_with(interval, "mac", "Unique devices")
		sensor_repeat %<>% prepare_with(interval, "mac", "Non repeating")
	}
	list(manual, sensor, sensor_range, sensor_unique, sensor_repeat) %>% bind_rows()
}
