# Load packages
library(leaflet)
library(jsonlite)
library(dplyr)
library(ggmap)
# I (Zeb) wrote this package! Code at https://www.github.com/zmbc/soql
library(soql)

endpoint_url <- "https://data.seattle.gov/resource/kzjm-xkqj.json"

data_soql_stump <- soql() %>%
  soql_add_endpoint(endpoint_url) %>% 
  soql_where("datetime IS NOT NULL") %>%
  soql_where("latitude IS NOT NULL") %>%
  soql_where("longitude IS NOT NULL")

recent_data <- data_soql_stump %>%
  soql_order("datetime", desc = TRUE) %>% 
  soql_limit(15) %>%
  as.character() %>% 
  fromJSON() %>% 
  flatten()

shinyServer(function(input, output) {
  output$recent_map <- renderLeaflet({
    leaflet() %>%
      setView(lat = 47.6097, lng = -122.3331, zoom = 10) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addCircleMarkers(
        data = recent_data,
        radius = ~(datetime - min(datetime)) / 300,
        fillOpacity = ~(datetime - min(datetime)) / (2*(max(datetime) - min(datetime))),
        stroke = FALSE,
        color = 'red',
        lat=~latitude,
        lng=~longitude,
        layerId=~incident_number
      )
  })
  
  observe({
    leafletProxy('recent_map') %>% clearPopups()
    clicked <- input$recent_map_marker_click
    if(is.null(clicked)) {
      return()
    }
    clicked_data <- recent_data %>% filter(incident_number == clicked$id)
    
    popup_contents <- as.character(tagList(
      format(as.POSIXlt(clicked_data$datetime, origin="1970-01-01"), format = "%D %r"), tags$br(),
      clicked_data$address, tags$br(),
      paste0("Type: ", clicked_data$type)
    ))
    leafletProxy('recent_map') %>% addPopups(clicked$lng, clicked$lat, popup_contents, layerId = clicked$id)
  })
  
  lat <- eventReactive(input$search, {
    geocode(input$address)
  })
  
  lng <- eventReactive(input$search, {
    geocode(input$address)
  })
  
  output$search_map <- renderLeaflet({
    leaflet() %>%
      setView(lat = lat(), lng = lng(), zoom = 13) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addCircleMarkers(
        data = recent_data,
        radius = ~(datetime - min(datetime)) / 300,
        fillOpacity = ~(datetime - min(datetime)) / (2*(max(datetime) - min(datetime))),
        stroke = FALSE,
        color = 'red',
        lat=~latitude,
        lng=~longitude,
        layerId=~incident_number
      )
  })
})