extract_sequences <- function(data,disth,timeth) {
	d <- 
		data %>%
		mutate(time=as.integer(time), id=rownames(data)) %>%
		select(time,sequence,id)
	dis_mat <-
		d %>%
		dist() %>%
		as.matrix()
	dis_mat[lower.tri(dis_mat)] <- 0
	dis_df <- 
		dis_mat %>%
		data.frame()
	colnames(dis_df) <- d$id
	dis_df <- 
		dis_df %>%
		mutate(from = d$id) %>%
		gather(to,value,-from) %>%
		filter(value < disth) %>%
		left_join(d,by=c("from"="id"))%>%
		left_join(d,by=c("to"="id")) %>%
		mutate(value = replace(value,time.y >= time.x,0),
			   value = replace(value,sequence.y >= sequence.x,0),
			   value = replace(value,time.y-time.x > timeth,0)) %>%
		select(from,to,value) %>%
		spread(to,value)
	dis_mat <- dis_df[,c(2:length(dis_df))] %>%
		as.matrix()
 	dis_mat[is.na(dis_mat)] <- 0
 	data$cluster <-
 		dis_mat %>%
 		graph_from_adjacency_matrix(.,mode="directed",weighted=TRUE) %>%
 		{walktrap.community(.)$membership}
 	gr <- graph_from_adjacency_matrix(dis_mat ,mode="directed",weighted=TRUE)
 	V(gr)$clust <- walktrap.community(gr)$membership
	V(gr)$x <- data$time
	V(gr)$y <- data$sequence
	return(gr)
}

input <- 
	subset_local %>%
	filter(vendor=="Google") 

plot_normal_data <- function(data) {
	data %>%
	ggplot() +
	geom_point(aes(time,sequence,col=as.character(mac)), show.legend=FALSE)
}

plot_class_data <- function(data,a,b) {
	data %>%
	extract_sequences(200,100) %>%
	ggplot() +
	geom_point(aes(time,sequence,col=as.character(cluster)))
}
