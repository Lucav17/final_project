library(leaflet)

shinyUI(
  navbarPage("Seattle Fire Dept. 9-1-1 Calls",
    tabPanel("Live Map",
      titlePanel("Recent Calls"),
      
      mainPanel(
        leafletOutput("recent_map")
      )
    ),
    tabPanel("Search",
      titlePanel("Search by Address"),
      
      sidebarLayout(
        sidebarPanel(
          div(textInput("address", "Enter Address:", value = "1314 6th Ave, Seattle, WA 98101"),
              actionButton("search", "Search Nearby Incidents"))
          ),
        mainPanel(
          leafletOutput("search_map")
        )
      )
    ),
    tabPanel("Timeline",
      tableOutput('timeline_data'),
      leafletOutput('heatmap'),
      tags$head(tags$script(src="http://leaflet.github.io/Leaflet.heat/dist/leaflet-heat.js")),
      uiOutput('heat')
             
      #sidebarLayout(
        #sidebarPanel(
                 
        #)
      #),
             
      #mainPanel(
        #plotlyOutput("timeline")
      #)
    )
  )
)