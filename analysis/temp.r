rm(list=ls())
x1 <- sample(1:20,10)
y1 <- (12 * x1) + 1
x2 <- sample(1:20,10)
y2 <- (4 * x2) + 6
x3 <- sample(1:20,10)
y3 <- (1 * x3) + 10
series1 <- data.frame(x=x1,y=y1)
series2 <- data.frame(x=x2,y=y2)
series3 <- data.frame(x=x3,y=y3)
comb <- rbind(series1,series2,series3)
comb <- comb %>% arrange(x)
k <- kmeans(comb,3)
ggplot(comb)+geom_point(aes(x,y),size=5)
ggplot(comb)+geom_point(aes(x,y,col=as.character(k$cluster)),size=5,show.legend=FALSE)
mat <- as.matrix(dist(comb))
df <- as.data.frame(mat)
df$from <- 1:nrow(df)
tab <- gather(df,"to","d",-from)
ggplot(tab)+geom_raster(aes(from,to,fill=d))
distance_fn <- function(x,y) {
	t1 <- x[,1]
	s1 <- x[,2]
	t2 <- y[,1]
	s2 <- y[,2]
	d <- sqrt(((t2-t1)**2)+((s2-s1)**2))
	if(s2<=s1) {
		d <- 0
	} else if(t2<=t1)  {
		d <- 0
	} else if (t2-t1 > 5) {
		d <-0
	} else if(d > 25){
		d <- 0
	}
	return(d)
}
distance <- as.matrix(dist_make(comb, distance_fn, method = NULL))
distance[lower.tri(distance)] <- 0

ig <- graph_from_adjacency_matrix(distance,mode="directed",weighted=TRUE)

V(ig)$x <- comb$x
V(ig)$y <- comb$y
comb$cluster <- walktrap.community(ig)$membership
plot(ig,vertex.color = comb$cluster,vertex.label=comb$y,vertex.size=12)
plot(ig,vertex.vertex.label=comb$y,vertex.size=12,vertex.label.size=2)

dist() %>% as.matrix() %>% data.frame() %>%
		rename_all(funs(gsub("X","",.))) %>%
		mutate(from = rownames(vertices)) %>%
		gather(to,value,-from) %>%

