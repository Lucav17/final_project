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
      titlePanel("???")
             
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