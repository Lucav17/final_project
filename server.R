# Load packages
library(leaflet)
library(jsonlite)
library(dplyr)
library(ggmap)
# I (Zeb) wrote this package! Code at https://www.github.com/zmbc/soql
library(soql)
library(shiny)
library(plotly)
library(data.table)

endpoint_url <- "https://data.seattle.gov/resource/kzjm-xkqj.json"

types <- list(boat = c("Boat%", "Ship%"),
              medic = "Medic Resp%",
              mvi = c("Motor Vehicle Accident%", "MVI%"),
              natural_gas = c("Natural Gas%"),
              quick_dispatch = "Q%",
              rescue = "Rescue%",
              tunnel = "Tunnel%",
              fire = "%Fire%",
              explosion = "Explosion%",
              assault = "Assault%",
              automatic = "Automatic%"
              )

data_soql_stump <- soql() %>%
  soql_add_endpoint(endpoint_url) %>%
  soql_select('*') %>%
  soql_where("datetime IS NOT NULL") %>%
  soql_where("latitude IS NOT NULL") %>%
  soql_where("longitude IS NOT NULL")



timeline_soql_stump <- soql() %>%
    # 2.1 version of the endpoint
    soql_add_endpoint('https://data.seattle.gov/resource/grwu-wqtk.json') %>%
    soql_select('date_trunc_ym(datetime) as month, count(datetime)') %>%
    soql_where('month IS NOT NULL') %>%
    soql_group('month') %>%
    soql_order('month')


heatmap_bins_select <- function(column, min, max, by, as) {
  bin_mins <- seq(from = min, to = max - by, by = by)
  case_clause <- paste0(column, '>=', bin_mins, ' AND ', column, '<', bin_mins + by)
  case_clause <- paste0(case_clause, ',', bin_mins)
  case_clause <- paste(case_clause, collapse = ',')
  return(paste0('case(', case_clause, ') as ', as))
}

heatmap_soql_stump <- soql() %>%
  # 2.1 version of the endpoint
  soql_add_endpoint('https://data.seattle.gov/resource/grwu-wqtk.json') %>%
  soql_select(heatmap_bins_select('longitude', -123, -122.2, 0.02, 'lon_bin')) %>%
  soql_select(heatmap_bins_select('latitude', 47.3, 48, 0.02, 'lat_bin')) %>%
  soql_group('lon_bin,lat_bin') %>%
  soql_select('count(longitude)') %>%
  soql_where('lon_bin IS NOT NULL') %>%
  soql_where('lat_bin IS NOT NULL')

shinyServer(function(input, output, session) {
  recent_data <- reactive({
    data_soql_stump %>%
      soql_order("datetime", desc = TRUE) %>% 
      soql_limit(input$amount) %>%
      as.character() %>% 
      fromJSON(flatten = TRUE)
  })
  
  output$recent_map <- renderLeaflet({
    leaflet() %>%
      setView(lat = 47.6097, lng = -122.3331, zoom = 10) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addCircleMarkers(
        data = recent_data(),
        radius = ~(((datetime - min(datetime)) / (max(datetime) - min(datetime))) * 10) + 1,
        fillOpacity = ~(datetime - (min(datetime)- 900)) / (2*(max(datetime) - min(datetime))),
        stroke = FALSE,
        color = '#FF4136',
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
    clicked_data <- recent_data() %>% filter(incident_number == clicked$id)
    
    popup_contents <- as.character(tagList(
      format(as.POSIXlt(clicked_data$datetime, origin="1970-01-01"), format = "%D %r"), tags$br(),
      clicked_data$address, tags$br(),
      paste0("Type: ", clicked_data$type)
    ))
    leafletProxy('recent_map') %>% addPopups(clicked$lng, clicked$lat, popup_contents, layerId = clicked$id)
  })
  
  lat_lon <- eventReactive(input$search, {
    geocode(input$address)
  })
  
  search_data <- reactive({
    data_soql_stump %>%
      soql_order("datetime", desc = TRUE) %>% 
      soql_where(paste0('within_circle(report_location,', lat_lon()$lat, ', ', lat_lon()$lon,', 1000)')) %>%
      as.character() %>% 
      fromJSON(flatten = TRUE)
  })
  
  output$search_map <- renderLeaflet({
    leaflet() %>%
      setView(lat = lat_lon()$lat, lng = lat_lon()$lon, zoom = 14) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addCircles(
        radius = 1000,
        color = 'blue',
        fillOpacity = 0,
        lat = lat_lon()$lat,
        lng = lat_lon()$lon
      ) %>%
      addCircleMarkers(
        data = search_data(),
        radius = 4,
        fillOpacity = 0.5,
        stroke = FALSE,
        color = '#FF4136',
        lat=~latitude,
        lng=~longitude,
        layerId=~incident_number
      ) %>%
      addMarkers(lng = lat_lon()$lon, lat = lat_lon()$lat, layerId='center')
  })
  
  observe({
    leafletProxy('search_map') %>% clearPopups()
    clicked <- input$search_map_marker_click
    if(is.null(clicked) || clicked$id == 'center') {
      return()
    }
    clicked_data <- search_data() %>% filter(incident_number == clicked$id)
    
    popup_contents <- as.character(tagList(
      format(as.POSIXlt(clicked_data$datetime, origin="1970-01-01"), format = "%D %r"), tags$br(),
      clicked_data$address, tags$br(),
      paste0("Type: ", clicked_data$type)
    ))
    leafletProxy('search_map') %>% addPopups(clicked$lng, clicked$lat, popup_contents, layerId = clicked$id)
  })
  
  observe({
    clicked <- input$search_map_click
    if(is.null(clicked)) {
      return()
    }
    
    location = revgeocode(c(clicked$lng, clicked$lat))
    updateTextInput(session, "address", value = location)
  })
  
  timeline_data <- reactive({
    chain <- timeline_soql_stump
    
    if(input$filter_by_category == 'yes') {
      type_patterns <- types[[input$category]]
      where_statement <- paste0("type like '", type_patterns, "'")
      where_statement <- paste0(where_statement, collapse = ' OR ')
      chain <- chain %>% soql_where(where_statement)
    }
    
    chain %>%
      as.character() %>%
      fromJSON(flatten = TRUE) %>%
      mutate(date = format(as.POSIXlt(month, origin="1970-01-01"), format = "%b"))
  })
  
  output$line <- renderPlotly({
    
    filter_year <- timeline_data() %>% filter(year(month) == input$year1)
  
    if(input$filter_by_year == 'yes') {
    timeline_data <- timeline_data() %>%  mutate(date = format(as.POSIXlt(month, origin="1970-01-01"), format = "%b"))
    plot_ly(
      filter_year, x = filter_year$date, y = filter_year$count_datetime, name = "Timeline", line = list(color = "#FF4136")) %>% 
      layout(title = paste('9-1-1 Calls for the Months of', input$year1, "For the Category"), 
             xaxis = list(title = paste('Months')),
             yaxis = list(title = paste("Number of Calls")))
    } else {
      new_data <- timeline_data() %>%  mutate(date = format(as.POSIXlt(month, origin="1970-01-01"), format = "%b %Y"))
      plot_ly(
        new_data, x = new_data$date, y = new_data$count_datetime, name = "Timeline", line = list(color = "#FF4136")) %>% 
        layout(title = paste('9-1-1 Calls for Every Month'), 
               xaxis = list(title = paste('Months'), showticklabels = FALSE),
               yaxis = list(title = paste("Number of Calls")))
    }
  })
  
  heatmap_data <- reactive({
    chain <- heatmap_soql_stump
    
    if(input$filter_by_category == 'yes') { 
      type_patterns <- types[[input$category]]
      where_statement <- paste0("type like '", type_patterns, "'")
      where_statement <- paste0(where_statement, collapse = ' OR ')
      chain <- chain %>% soql_where(where_statement)
    }
    
    if(input$filter_by_year == 'yes') {
      return(chain %>%
        soql_where(paste0("date_trunc_y(datetime)='", input$year1,"-01-01T00:00:00.000'")) %>%
        as.character() %>%
        fromJSON(flatten = TRUE) %>%
        mutate_each(funs(as.numeric), c(lon_bin, lat_bin, count_longitude)))
    } else {
      return(chain %>%
        as.character() %>%
        fromJSON(flatten = TRUE) %>%
        mutate_each(funs(as.numeric), c(lon_bin, lat_bin, count_longitude)))
    }
  })
  
  output$heatmap <-renderLeaflet({
    leaflet() %>%
      setView(lat = 47.6097, lng = -122.3331, zoom = 10) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addRectangles(
        data = isolate(heatmap_data()),
        lng1=~lon_bin, lat1=~lat_bin,
        lng2=~lon_bin + 0.02, lat2=~lat_bin + 0.02,
        stroke = FALSE,
        fillColor = '#FF4136',
        fillOpacity = ~count_longitude * 0.8 / max(count_longitude),
        layerId=~paste0(as.character(lat_bin), ' ', as.character(lon_bin))
      )
  })
  
  observe({
    input$year1
    input$filter_by_year
    
    leafletProxy('heatmap') %>% clearShapes()
    leafletProxy('heatmap') %>%
      addRectangles(
        data = heatmap_data(),
        lng1=~lon_bin, lat1=~lat_bin,
        lng2=~lon_bin + 0.02, lat2=~lat_bin + 0.02,
        stroke = FALSE,
        fillColor = '#FF4136',
        fillOpacity = ~count_longitude * 0.8 / max(count_longitude),
        layerId=~paste0(as.character(lat_bin), ' ', as.character(lon_bin))
      )
  })
  
  observe({
    leafletProxy('heatmap') %>% clearPopups()
    clicked <- input$heatmap_shape_click
    if(is.null(clicked)) {
      return()
    }
    lat_lon_bins <- strsplit(clicked$id, ' ')
    lat_lon_bins <- lapply(lat_lon_bins, as.numeric)[[1]]
    clicked_data <- heatmap_data() %>% filter(lat_bin == lat_lon_bins[1], lon_bin == lat_lon_bins[2])
    
    popup_contents <- paste0('Calls: ', as.character(clicked_data$count_longitude))
    leafletProxy('heatmap') %>% addPopups(clicked$lng, clicked$lat, popup_contents, layerId = clicked$id)
  })
})