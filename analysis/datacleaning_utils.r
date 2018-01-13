generate_vendor_file <- function(vendor,location) {
	vendor %>%
		unique %>%
		sort %>%
		data.frame(vendor = ., is_mobile = rep(TRUE, length(.))) %>%
		write.csv(location,row.names=FALSE)
}
