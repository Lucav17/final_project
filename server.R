# Load packages
library(leaflet)
library(jsonlite)
library(dplyr)
library(ggmap)
# I (Zeb) wrote this package! Code at https://www.github.com/zmbc/soql
library(soql)

# Retrieve data
endpoint_url <- "https://data.seattle.gov/resource/kzjm-xkqj.json"

shinyServer(function(input, output) {
  live_data <- reactive({
    soql() %>%
      soql_add_endpoint(endpoint_url) %>% 
      soql_where("datetime IS NOT NULL") %>%
      soql_where("latitude IS NOT NULL") %>%
      soql_where("longitude IS NOT NULL") %>% 
      soql_order("datetime", desc = TRUE) %>% 
      soql_limit(15) %>%
      as.character() %>% 
      fromJSON() %>% 
      flatten()
  })
  
  lat <- eventReactive(input$search, {
    geocode(input$address)
  })
  
  lng <- eventReactive(input$search, {
    geocode(input$address)
  })
  
  output$map <- renderLeaflet({
    leaflet() %>%
      setView(lat = 47.6097, lng = -122.3331, zoom = 10) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addCircleMarkers(
        data = live_data(),
        radius = ~(datetime - min(datetime)) / 300,
        fillOpacity = ~(datetime - min(datetime)) / (2*(max(datetime) - min(datetime))),
        stroke = FALSE,
        color = 'red',
        lat=~latitude,
        lng=~longitude,
        layerId=~incident_number
      )
  })
  
  output$search_map <- renderLeaflet({
    leaflet() %>%
      setView(lat = lat(), lng = lng(), zoom = 13) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addCircleMarkers(
        data = live_data(),
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