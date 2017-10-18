library(plumber)

serve_model <- plumb("titanic-api.R")
serve_model$run(port = 8000)
