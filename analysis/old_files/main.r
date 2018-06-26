suppressMessages(library('tidyverse'))
suppressMessages(library('ggplot2'))

if(!exists("locations")) { locations <- read.csv("../data/main_locations.csv") }
if(!exists("manual")) { manual <- read.csv("../data/main_manual.csv") }
if(!exists("sensor")) { sensor <- read.csv("../data/main_probes.csv") }

if(!exists("vendors")) {
	vendors <- (function(url = "https://goo.gl/RzzYwh") {
		lines <- readLines(url)
		lines <- lines[!substring(lines, 1, 1) == '#']
		lines <- lines[!lines == '']
		lines <- lapply(lines, function(x) {
							 record <- strsplit(x, '((\t))+')[[1]]
							 if(is.na(record[4])) { record[4] = '' }
							 if(is.na(record[3])) { record[3] = '' }
							 if(length(record) > 4) { record = record[1:4] }
							 return(record) })
		lines <- data.frame(matrix(
								   unlist(lines), 
								   nrow = length(lines), 
								   byrow = T), 
							stringsAsFactors = FALSE)
		names(lines) <- c("oui", "vendor", "vendor_long", "comments")
		lines <- lines[nchar(lines$oui) == 8, ]
		lines$oui <- strsplit(lines$oui, ':') %>% 
			lapply(function(x) { paste0(x, collapse = '') }) %>%
			unlist() %>%
			tolower()
		return(lines) })() }

if(is.null(sensor$vendor)) {
	sensor <- merge(sensor, vendors[, 1:2], by = "oui", all.x = TRUE)[, union(names(sensor), names(vendors[, 1:2]))] }

if(exists(sensor$oui_type)) {
	sensor$oui_type <- ifelse(substr(sensor$oui, 2, 2) %in% c('2', '6', 'e', 'a'), "local", "global") }
