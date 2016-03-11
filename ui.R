library(leaflet)
library(shiny)
library(plotly)

shinyUI(
  navbarPage("Seattle Fire Dept. 9-1-1 Calls",
    tabPanel("Live Map",
      titlePanel("Recent Calls"),
      
          sidebarLayout(
              sidebarPanel(
                  selectInput("amount", label = h3("Select number of most recent calls to see"), selected = '15',
                                 choices = list("15" = '15',
                                                "25" = '25',
                                                "50" = '50',
                                                "75" = '75',
                                                "100" = '100',
                                                "500" = '500',
                                                "1000" = '1000'))
              ),
              mainPanel(
                leafletOutput("recent_map")
              )
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
    tabPanel("Graphs",
      sidebarLayout(
        sidebarPanel(
          selectInput("category", label = h3("Select 9-1-1 Call Category"), selected = 'boat',
                      choices = list("Boat" = "boat",
                                     "Medic" = "medic",
                                     "Natural Gas" = "natural_gas",
                                     "Rescue" = "rescue",
                                     "Tunnel" = "tunnel",
                                     "Fire" = "fire",
                                     "Explosion" = "explosion",
                                     "Assault" = "assault",
                                     "Assault" = "assault")),
          
          radioButtons("type", label = h3("Select Data Type"), selected = 'Entire Data Frame',
                       choices = list("Entire Data Frame" = 'no', "By Year" = 'yes')),
          
          conditionalPanel(condition = "input.type == 'yes'",
                           selectInput("year1", label = h3("Select Year"), selected = '2015',
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
          tabsetPanel(
            tabPanel("Timeline", plotlyOutput('line')),
            tabPanel("Heatmap", leafletOutput('heatmap'))
          )
        )
      )
    )
  )
)