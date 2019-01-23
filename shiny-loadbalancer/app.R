
library(shiny)

ui <- fluidPage(
  titlePanel("My Shiny App"),
  mainPanel(
    actionButton("button", "Randomize"),
    plotOutput("distPlot")
  )
)

server <- function(input, output) {
  output$distPlot <- renderPlot({
    input$button
    hist(rnorm(1000, 0, 1), breaks = 30, 
         col = 'darkgray', border = 'white')
  })
}

shinyApp(ui = ui, server = server)

