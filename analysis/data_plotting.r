# ==============================================================================
# This needs to be run after creating objects from data_cleaning script
# ------------------------------------------------------------------------------
# Creating a series of plots of the data for communications
# ==============================================================================

# ------------------------------------------------------------------------------
# Plot objects
# ------------------------------------------------------------------------------
p_comp <- bind_rows(count_all,count_data_00) %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00"),
		   type %in% c("01 Filtered out low signal strength",
					   "03 Filter out randomised MACs",
					   "05 Manual counting",
					   "00 No filtering")) %>%
	ggplot()+
	geom_line(aes(time,footfall, group = type, col=type),size = 0.5, show.legend=FALSE)+
	geom_point(aes(time,footfall, shape = type,col=type),size = 2.5)+
	theme(legend.position = "bottom") +
	xlab("") +
	ylab("") +
	scale_colour_manual(values=c("#333333","#377eb8","#4daf4a","#e41a1c")) +
	theme(panel.background=element_blank())
p_comp

p_comparison <- bind_rows(count_all,count_data_00) %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00"),
		   type %in% c("01 Filtered out low signal strength",
					   "03 Filter out randomised MACs",
					   "05 Manual counting",
					   "00 No filtering")) %>%
	ggplot()+
	geom_line(aes(time,footfall,col = type),
			  linejoin="round",
			  lineend="round",
			  size = 2,
			  show.legend=FALSE)+
	theme(legend.position = "bottom") +
	xlab("") +
	ylab("") +
	scale_colour_manual(values = c("#e41a1c","#4daf4a","#377eb8","#984ea3")) +
	theme(panel.background=element_blank())

p_sig <- data_00 %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00")) %>%
	ggplot() +
	geom_point(aes(time,signal),
			   size = 0.5,
			   show.legend = FALSE) +
	xlab("") +
	ylab("") +
	theme(panel.background=element_blank())

p_sig_both <- data_00 %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00")) %>%
	ggplot() +
	geom_point(aes(time,signal,col=sig),
			   size = 0.5,
			   show.legend = FALSE) +
	xlab("") +
	ylab("") +
	scale_colour_manual(values = c("#e41a1c","#4daf4a")) +
	theme(panel.background=element_blank())

p_sig_one <- data_00 %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00")) %>%
	ggplot() +
	geom_point(aes(time,signal,col=sig),
			   size = 0.5,
			   show.legend = FALSE) +
	xlab("") +
	ylab("") +
	scale_colour_manual(values = c("#ffffff","#4daf4a")) +
	theme(panel.background=element_blank())

p_sig_dist <- data_00 %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00")) %>%
	ggplot() +
	geom_histogram(aes(signal,fill=sig),
			   size = 0.5,
			   show.legend = FALSE) +
	xlab("") +
	ylab("") +
	scale_fill_manual(values = c("#e41a1c","#4daf4a")) +
	theme(panel.background=element_blank())

p_global <- subset_global %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00")) %>%
	ggplot() + 
	geom_point(aes(time,sequence),
			   size = 1,
			   show.legend = FALSE) +
	theme(legend.position = "bottom")

p_seq_all <- bind_rows(subset_local,subset_global) %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00")) %>%
	ggplot() + 
	geom_point(aes(time,sequence),
			   size = 1,
			   show.legend = FALSE)  +
	xlab("") +
	ylab("") +
	theme(legend.position = "bottom") +
	theme(panel.background=element_blank())

p_seq_both <- bind_rows(subset_local,subset_global) %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00")) %>%
	ggplot() + 
	geom_point(aes(time,sequence,col=type),
			   size = 1,
			   show.legend = FALSE) +
	xlab("") +
	ylab("") +
	scale_colour_manual(values = c("#e41a1c","#4daf4a")) +
	theme(panel.background=element_blank())

p_seq_one <- bind_rows(subset_local) %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00")) %>%
	ggplot() + 
	geom_point(aes(time,sequence),
			   size = 1,
			   col="#4daf4a",
			   show.legend = FALSE) +
	xlab("") +
	ylab("") +
	theme(panel.background=element_blank())


p_local_cluster <- subset_local %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 13:00:00")) %>%
	ggplot() + 
	geom_point(aes(time,sequence),
			   size = 0.5,
			   col = "black",
			   show.legend = FALSE) +
	geom_line(aes(time,
				  sequence,
				  group = device_sign),
			  size = 2,
			  color = "blue",
			  lineend = "round",
			  linejoin = "round",
			  alpha = 0.4,
			  show.legend = FALSE) +
	xlab("") +
	ylab("") +
	theme(panel.background=element_blank())

clustering_schematic <- subset_local %>%
	filter(time >= as.POSIXct("2017-12-20 12:30:00"),
		   time <= as.POSIXct("2017-12-20 12:40:00"),
		   sequence < 2000) %>%
	ggplot() + 
	geom_point(aes(time,sequence,fill=mac),
			   size = 4,
			   shape = 21,
			   color = "grey",
			   stroke = 0.5,
			   show.legend = FALSE) +
	geom_line(aes(time,
				  sequence,
				  group = device_sign),
			  # arrow = arrow(length=unit(0.1,"cm"), ends="last", type = "closed"),
			  size = 1,
			  # color = "#e41a1c",
			  lineend = "round",
			  linejoin = "round",
			  color = "#333333",
			  show.legend = FALSE) +
	xlab("") +
	ylab("") +
	theme(panel.background=element_blank())
clustering_schematic
