library(plumber)
model <- readRDS("model/model.Rds")

MODEL_VERSION <- "0.0.1"
VARIABLES <- list(
  pclass = "Pclass = 1, 2, 3 (Ticket Class: 1st, 2nd, 3rd)",
  sex = "Sex = male or female",
  age = "Age = # in years",
  gap = "",
  survival = "Successful submission will results in a calculated Survival Probability from 0 to 1 (Unlikely to More Likely)"
  )


# test API working --------------------------------------------------------

#* @get /healthcheck
health_check <- function() {
  result <- data.frame(
    "input" = "",
    "status" = 200,
    "model_version" = MODEL_VERSION
  )
  
  return(result)
}


# API landing page --------------------------------------------------------

#* @get /
#* @html
home <- function() {
  title <- "Titanic Survival API"
  body_intro <-  "Welcome to the Titanic Survival API!"
  body_model <- paste("We are currently serving model version:", MODEL_VERSION)
  body_msg <- paste("To received a prediction on survival probability,", 
                     "submit the following variables to the <b>/survival</b> endpoint:",
                     sep = "\n")
  body_reqs <- paste(VARIABLES, collapse = "<br>")
  
  result <- paste(
    "<html>",
    "<h1>", title, "</h1>", "<br>",
    "<body>", 
    "<p>", body_intro, "</p>",
    "<p>", body_model, "</p>",
    "<p>", body_msg, "</p>",
    "<p>", body_reqs, "</p>",
    "</body>",
    "</html>",
    collapse = "\n"
  )
  
  return(result)
}


# helper functions for predict --------------------------------------------

transform_titantic_data <- function(input_titantic_data) {
  ouput_titantic_data <- data.frame(
    pclass = factor(input_titantic_data$Pclass, levels = c(1, 2, 3)),
    female = tolower(input_titantic_data$Sex) == "female",
    age = factor(dplyr::if_else(input_titantic_data$Age < 18, "child", "adult", "unknown"), 
                 levels = c("child", "adult", "unknown"))
  )
}

validate_feature_inputs <- function(age, pclass, sex) {
  age_valid <- (age >= 0 & age < 200 | is.na(age))
  pclass_valid <- (pclass %in% c(1, 2, 3))
  sex_valid <- (sex %in% c("male", "female"))
  tests <- c("Age must be between 0 and 200 or NA", 
             "Pclass must be 1, 2, or 3", 
             "Sex must be either male or female")
  test_results <- c(age_valid, pclass_valid, sex_valid)
  if(!all(test_results)) {
    failed <- which(!test_results)
    return(tests[failed])
  } else {
    return("OK")
  }
}


# predict endpoint --------------------------------------------------------

#* @post /survival
#* @get /survival
predict_survival <- function(Age=NA, Pclass=NULL, Sex=NULL) {
  age = as.integer(Age)
  pclass = as.integer(Pclass)
  sex = tolower(Sex)
  valid_input <- validate_feature_inputs(age, pclass, sex)
  if (valid_input[1] == "OK") {
    payload <- data.frame(Age=age, Pclass=pclass, Sex=sex)
    clean_data <- transform_titantic_data(payload)
    prediction <- predict(model, clean_data, type = "response")
    result <- list(
      input = list(payload),
      reposnse = list("survival_probability" = prediction,
                      "survival_prediction" = (prediction >= 0.5)
                      ),
      status = 200,
      model_version = MODEL_VERSION)
  } else {
    result <- list(
      input = list(Age = Age, Pclass = Pclass, Sex = Sex),
      response = list(input_error = valid_input),
      status = 400,
      model_version = MODEL_VERSION)
  }

  return(result)
}
