get_membership <- function(data,distance){
	vertices <- data %>%
		mutate(time = as.integer(time), id = rownames(data)) %>%
		select(id,time,sequence) 
	edges <- 
		vertices %>%
		dist() %>% as.matrix() %>% data.frame() %>%
		rename_all(funs(gsub("X","",.))) %>%
		mutate(from = rownames(vertices)) %>%
		gather(to,value,-from) %>%
		left_join(vertices,by = c("from"="id")) %>%
		left_join(vertices,by = c("to"="id")) %>%
		filter(value < distance,
			   time.y >= time.x,
			   sequence.y > sequence.x)
	graph <- 
		edges %>%
		graph_from_data_frame(vertices = vertices %>%
										 rename(x=time,y=sequence))
	clusters(graph)$membership
}
