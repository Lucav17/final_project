library(jsonlite)
# Retrieve data
endpoint_url <- "https://data.seattle.gov/resource/kzjm-xkqj.json"
num_rows <- as.numeric(fromJSON(paste0(endpoint_url, "?$select=count(type)"))[1,])
data <- flatten(fromJSON(paste0(endpoint_url, "?$select=*&$order=:id&$limit=50000")))
# Loop through pages
# Comment out these lines to test with less data
for(i in seq(from = 50000, to = num_rows, by = 50000)) {
  request_url <- paste0(endpoint_url, "?$select=*&$order=:id&$limit=50000&$offset=", i)
  data <- rbind(data, flatten(fromJSON(request_url)))
}
# http://stackoverflow.com/a/22960230/5981634
data <- data %>% group_by(type, address, latitude, longitude, incident_number) %>% 
                  filter(row_number() == 1)
data$id <- seq(1, nrow(data))
# Convert from unix timestamp
data <- data %>% mutate(datetime = as.POSIXct(datetime, origin="1970-01-01"))


shinyServer(function(input, output) {
  
})