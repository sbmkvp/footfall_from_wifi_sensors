library(tidyverse)
library(igraph)
data <- subset_local %>% filter(vendor=="Google")
data <- subset_local %>% filter(vendor=="Unknown")
vertices <- data %>%
	mutate(x = as.integer(time), id = as.numeric(rownames(data))) %>%
	select(id, x, y=sequence) %>%
	arrange(x)
edges <- vertices %>%
	pull(id) %>%
	expand.grid(.,.) %>% rename(from=Var1,to=Var2) %>%
	mutate(from=as.numeric(from), to=as.numeric(to)) %>%
	filter(from<to) %>%
	left_join(vertices, by = c("from" = "id")) %>%
	left_join(vertices, by = c("to" = "id")) %>%
	mutate(distance = sqrt(((x.y-x.x)**2)+((y.y-y.x)**2))) %>%
	mutate(tdistance = sqrt((x.y-x.x)**2)) %>%
	filter(x.y >= x.x, y.y > y.x, distance < 68) %>%
	group_by(from) %>%
	summarise(to = to[which(distance == min(distance))][[1]], distance=min(distance)) %>%
	group_by(to) %>%
	summarise(from = from[which(distance == min(distance))][[1]])

print(nrow(edges))
graph <- graph_from_data_frame(edges, vertices = vertices)
clusters <- clusters(graph)$membership
plot(graph,vertex.size=2,edge.arrow.size=0,vertex.label=NA,vertex.frame.color="orange")
plot(graph,vertex.size=2,edge.arrow.size=0,vertex.label=NA,vertex.frame.color=clusters,vertex.color=clusters)
