library(leaflet)
library(shiny)
library(plotly)

shinyUI(
  navbarPage("Seattle Fire Dept. 9-1-1 Calls",
    tabPanel("Live Map",
      headerPanel("Live Calls"),
      sidebarLayout(
        sidebarPanel(
          tags$p("This map shows the most recent 9-1-1 calls recieved by the
                  Seattle fire department. Each red marker represents an event 
                  that occured just moments ago in and around Seattle. The larger
                  and brighter the marker, the more recently the event has occured. 
                  If you click on a marker, a box containing information about the
                  event that took place will appear. Our data comes from the City of 
                  Seattle and is updated every 5 mins."),
          tags$p("Created by @zmbc, @soccerdude2014, @Lucav17, and @LunoA."),
          sliderInput("amount", label = h4("Calls shown:"), min = 1, max = 1000, value = 15),
          radioButtons("live_just_fires", label = h4("Call type"), selected = 'no',
                       choices = list('All' = 'no', 'Fires only' = 'yes'))
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
    tabPanel("Data",
      sidebarLayout(
        sidebarPanel(
          radioButtons("filter_by_category", label = h3("Filter by category"), selected = 'no',
                       choices = list('All' = 'no', 'Individual category' = 'yes')),
          conditionalPanel(condition = "input.filter_by_category == 'yes'",
            selectInput("category", label = h4("Select category"), selected = 'boat',
                       choices = list("Boat" = "boat",
                                      "Medic" = "medic",
                                      "Natural Gas" = "natural_gas",
                                      "Rescue" = "rescue",
                                      "Tunnel" = "tunnel",
                                      "Fire" = "fire",
                                      "Explosion" = "explosion",
                                      "Assault" = "assault",
                                      "Assault" = "assault"))
          ),
          radioButtons("filter_by_year", label = h3("Filter by year"), selected = 'no',
                       choices = list("All years" = 'no', "Individual year" = 'yes')),
          
          conditionalPanel(condition = "input.filter_by_year == 'yes'",
                           selectInput("year1", label = h4("Select year"), selected = '2015',
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
    ),
    conditionalPanel(condition="$('html').hasClass('shiny-busy')",
                     tags$img(src = 'loading.gif', class = 'loader')
    ),
    theme = "fire.css"
  )
)