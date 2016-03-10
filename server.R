# Load packages
library(leaflet)
library(jsonlite)
library(dplyr)
library(ggmap)
# I (Zeb) wrote this package! Code at https://www.github.com/zmbc/soql
library(soql)
library(shiny)
library(plotly)

endpoint_url <- "https://data.seattle.gov/resource/kzjm-xkqj.json"

data_soql_stump <- soql() %>%
  soql_add_endpoint(endpoint_url) %>%
  soql_select('*') %>%
  soql_where("datetime IS NOT NULL") %>%
  soql_where("latitude IS NOT NULL") %>%
  soql_where("longitude IS NOT NULL")

recent_data <- data_soql_stump %>%
  soql_order("datetime", desc = TRUE) %>% 
  soql_limit(15) %>%
  as.character() %>% 
  fromJSON(flatten = TRUE)

timeline_data <- soql() %>%
    # 2.1 version of the endpoint
    soql_add_endpoint('https://data.seattle.gov/resource/grwu-wqtk.json') %>%
    soql_select('date_trunc_ym(datetime) as month, count(datetime)') %>%
    soql_where('month IS NOT NULL') %>%
    soql_group('month') %>%
    soql_order('month') %>%
    as.character() %>%
    fromJSON(flatten = TRUE) %>%  mutate(date = format(as.POSIXlt(month, origin="1970-01-01"), format = "%b"))


heatmap_bins_select <- function(column, min, max, by, as) {
  bin_mins <- seq(from = min, to = max - by, by = by)
  case_clause <- paste0(column, '>=', bin_mins, ' AND ', column, '<', bin_mins + by)
  case_clause <- paste0(case_clause, ',', bin_mins)
  case_clause <- paste(case_clause, collapse = ',')
  return(paste0('case(', case_clause, ') as ', as))
}

heatmap_data <- soql() %>%
  # 2.1 version of the endpoint
  soql_add_endpoint('https://data.seattle.gov/resource/grwu-wqtk.json') %>%
  soql_select(heatmap_bins_select('longitude', -123, -122.2, 0.02, 'lon_bin')) %>%
  soql_select(heatmap_bins_select('latitude', 47.3, 48, 0.02, 'lat_bin')) %>%
  soql_group('lon_bin,lat_bin') %>%
  soql_select('count(longitude)') %>%
  soql_where('lon_bin IS NOT NULL') %>%
  soql_where('lat_bin IS NOT NULL') %>%
  as.character() %>%
  fromJSON(flatten = TRUE)

heatmap_data$lon_bin <- as.numeric(heatmap_data$lon_bin)
heatmap_data$lat_bin <- as.numeric(heatmap_data$lat_bin)
heatmap_data$count_longitude <- as.numeric(heatmap_data$count_longitude)

shinyServer(function(input, output) {
  output$recent_map <- renderLeaflet({
    leaflet() %>%
      setView(lat = 47.6097, lng = -122.3331, zoom = 10) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addCircleMarkers(
        data = recent_data,
        radius = ~(datetime - (min(datetime) - 600)) / 300,
        fillOpacity = ~(datetime - (min(datetime)- 600)) / (2*(max(datetime) - min(datetime))),
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
        color = 'red',
        lat=~latitude,
        lng=~longitude,
        layerId=~incident_number
      )
  })
  
  observe({
    leafletProxy('search_map') %>% clearPopups()
    clicked <- input$search_map_marker_click
    if(is.null(clicked)) {
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
  
  output$line <- renderPlotly({
    filter_year <- switch(input$year, 
                          '2010' = timeline_data %>% filter(year(month) == '2010'),
                          '2011' = timeline_data %>% filter(year(month) == '2011'),
                          '2012' = timeline_data %>% filter(year(month) == '2012'),
                          '2013' = timeline_data %>% filter(year(month) == '2013'),
                          '2014' = timeline_data %>% filter(year(month) == '2014'),
                          '2015' = timeline_data %>% filter(year(month) == '2015'),
                          '2016' = timeline_data %>% filter(year(month) == '2016'))
    if(input$type == 'yes') {
    timeline_data <- timeline_data %>%  mutate(date = format(as.POSIXlt(month, origin="1970-01-01"), format = "%b"))
    plot_ly(
      filter_year, x = filter_year$date, y = filter_year$count_datetime, name = "unemployment") %>% 
      layout(title = paste('9-1-1 Calls for the Months of', input$year), 
             xaxis = list(title = paste('Months')),
             yaxis = list(title = paste("Number of Calls")))
    } else {
      new_data <- timeline_data %>%  mutate(date = format(as.POSIXlt(month, origin="1970-01-01"), format = "%b %Y"))
      plot_ly(
        new_data, x = new_data$date, y = new_data$count_datetime, name = "unemployment") %>% 
        layout(title = paste('9-1-1 Calls for the Months of'), 
               xaxis = list(title = paste('Months'), showticklabels = FALSE),
               yaxis = list(title = paste("Number of Calls")))
    }
  })
  output$timeline_data <- renderTable({timeline_data})
  
  output$heatmap <-renderLeaflet({
    leaflet() %>%
      setView(lat = 47.6097, lng = -122.3331, zoom = 10) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addRectangles(
        data = heatmap_data,
        lng1=~lon_bin, lat1=~lat_bin,
        lng2=~lon_bin + 0.02, lat2=~lat_bin + 0.02,
        stroke = FALSE,
        fillColor = 'red',
        fillOpacity = ~count_longitude * 0.8 / max(count_longitude)
      )
  })
})