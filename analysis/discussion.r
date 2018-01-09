rm(list = ls())
source("analysis4Jan.r")
ucl_data_1min <- list(
			  analyse_data(sensor="../data/01#uclcloisters/sensor_cleaned.csv",interval=1),
			  read.csv("../data/01#uclcloisters/manual.csv") %>%
				  rename(footfall=count) %>%
				  mutate(action="Manual counts",time=as.POSIXct(time)) %>%
				  as_tibble()) %>%
	bind_rows()

ucl_data_5min <- list(
			  analyse_data(sensor="../data/01#uclcloisters/sensor_cleaned.csv",interval=5),
			  read.csv("../data/01#uclcloisters/manual.csv") %>%
				  rename(footfall=count) %>%
				  mutate(time=as.POSIXct(time)) %>%
				  set_interval(5) %>%
				  group_by(time) %>%
				  summarise(footfall = sum(footfall)) %>%
				  mutate(action="Manual counts") %>%
				  as_tibble()) %>%
	bind_rows()

oxst_data_1min <-
	analyse_data(
				 manual = "../data/02#oxfordst/20171220_manual.csv",
				 sensor = "../data/02#oxfordst/20171220_laptop.csv",
				 interval = 1)

oxst_data_5min <-
	analyse_data(
				 manual = "../data/02#oxfordst/20171220_manual.csv",
				 sensor = "../data/02#oxfordst/20171220_laptop.csv",
				 interval = 5)


plot_data <- function(data,fields=NULL) {
	if(is.null(fields)) fields = unique(data$action)
	data %>%
		filter(action%in%fields) %>%
		ggplot() +
		geom_line(aes(time, footfall, col = action))+
		theme(legend.position = "bottom") +
		labs(col="") %>%
		return
}
