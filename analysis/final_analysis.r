rm(list=ls())
library(tidyverse)
library(magrittr)

# we need to read data first.
sensor <-
	"../data/oxst_sensor.csv" %>%
	read.csv(stringsAsFactors = FALSE) %>%
	as_tibble() %>%
	mutate(X=NULL,
		   sig=cut(signal,
				   classIntervals(signal, 2, "kmeans")$brks,
				   c("low","high"))) %>%
	print()

# Reclassifying some data by combining last 40%

