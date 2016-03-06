# Load packages
library(leaflet)
library(jsonlite)
library(dplyr)
# Retrieve data
endpoint_url <- "https://data.seattle.gov/resource/kzjm-xkqj.json"

shinyServer(function(input, output) {
  live_data <- reactive({
    fromJSON(paste0(endpoint_url, "?$where=datetime%20IS%20NOT%20NULL%20AND%20latitude%20IS%20NOT%20NULL%20AND%20longitude%20IS%20NOT%20NULL&$order=datetime%20DESC&$limit=15")) %>% 
      flatten()
  })
  
  output$map <- renderLeaflet({
    leaflet() %>%
      setView(lat = 47.6097, lng = -122.3331, zoom = 10) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addCircleMarkers(
        data = live_data(),
        radius = 10,
        fillOpacity = 0.5,
        stroke = FALSE,
        color = 'red',
        lat=~latitude,
        lng=~longitude,
        layerId=~incident_number
      )
  })
  
  observe({
    leafletProxy('map') %>% clearPopups()
    clicked <- input$map_marker_click
    if(is.null(clicked)) {
      return()
    }
    clicked_data <- live_data() %>% filter(incident_number == clicked$id)
    
    popup_contents <- as.character(tagList(
      format(as.POSIXlt(clicked_data$datetime, origin="1970-01-01"), format = "%D %r"), tags$br(),
      clicked_data$address, tags$br(),
      paste0("Type: ", clicked_data$type)
    ))
    leafletProxy("map") %>% addPopups(clicked$lng, clicked$lat, popup_contents, layerId = clicked$id)
  })
})