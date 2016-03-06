library(jsonlite)
endpoint_url <- "https://data.seattle.gov/resource/kzjm-xkqj.json"
num_rows <- as.numeric(fromJSON(paste0(endpoint_url, "?$select=count(type)"))[1,])
data <- flatten(fromJSON(paste0(endpoint_url, "?$select=*&$limit=50000")))
for(i in seq(from = 50000, to = num_rows, by = 50000)) {
  request_url <- paste0(endpoint_url, "?$select=*&$limit=50000&$offset=", i)
  data <- rbind(data, flatten(fromJSON(request_url)))
}


shinyServer(function(input, output) {
  
})