rm(list=ls())
options(width = as.integer(Sys.getenv("COLUMNS")))

library(tidyverse)

data <- read.csv("../data/final_sensor_data.csv") %>% mutate(id=1:60040,time = as.POSIXct(time, format = "%b %d, %Y %H:%M:%OS")) %>% filter(type == "local") %>% filter(vendor == "Google") %>% select(id, time,seq = sequence)

dist_fun <- function(a, b) { return( ifelse (a > b, 4096 - a + b, 0) ) }

mat <- data %>% pull(id) %>% expand.grid(.,.) %>% 
	rename(x=Var1,y=Var2) %>% mutate(x=as.numeric(x), y=as.numeric(y)) %>%
	filter(x<y) %>%
	left_join(data, by = c("x" = "id")) %>%
	left_join(data, by = c("y" = "id")) %>%
	mutate(tdis = as.numeric(time.y - time.x), sdis = dist_fun(seq.x,seq.y) ) %>%
	filter(tdis < 17, sdis < 61, sdis != 0 )
