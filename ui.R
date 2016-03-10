library(leaflet)
library(shiny)

shinyUI(
  navbarPage("Seattle Fire Dept. 9-1-1 Calls",
    tabPanel("Live Map",
      titlePanel("Recent Calls"),
      leafletOutput("recent_map")
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
             
      sidebarLayout(
        sidebarPanel(
          
          radioButtons("type", label = h3("Select Data Type"), selected = 'Entire Data Frame',
                       choices = list("Entire Data Frame" = 'no', "By Year" = 'yes')),
          
          conditionalPanel(condition = "input.type == 'yes'",
            selectInput("year", label = h3("Select Year"), selected = '2015',
                        choices = list("2010" = "2010",
                           "2011" = "2011",
                           "2012" = "2012",
                           "2013" = "2013",
                           "2014" = "2014",
                           "2015" = "2015",
                           "2016" = "2016"))
  
          )
          ),
        
        mainPanel(
          #tableOutput('timeline_data')
          plotlyOutput('line')
        )
      ),
      
    tabPanel("Graphs",
      tabsetPanel(
        tabPanel("Timeline", tableOutput('timeline_data')),
        tabPanel("Heatmap", leafletOutput('heatmap'))
      )

    )
  )
)
)