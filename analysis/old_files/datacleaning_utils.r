# ==============================================================================
# Generate a vendor list
# ------------------------------------------------------------------------------
# This generates a csv file of the name specified from the vendor vector given.
# Unique vendors are extracted and sorted alphabatically with all of them being
# marked as mobile vendors
# ==============================================================================

generate_vendor_file <- function(vendor,location) {
	vendor %>%
		unique %>%
		sort %>%
		data.frame(vendor = ., is_mobile = rep(TRUE, length(.))) %>%
		write.csv(location,row.names=FALSE)
}
