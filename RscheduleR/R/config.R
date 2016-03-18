

#' @title Creates a user.config.json file of a scheduleR instance.
#' @description Creates a user.config.json file of a scheduleR instance.
#' This file contains information about the mongo database and how to mail results of scheduleR.
#' 
#' @export 
#' @param uploadDir scheduleR path to upload your scripts to at the scheduleR server. Defaults to /home/scheduler/scripts
#' @param errorNotificationMailAddresses character vector of email addresses that will be added to the recipients of error notification mails
#' @param mailer.from the google mail address which will be shown if a mail is sent out from scheduleR in case of success/failure
#' @param mailer.auth.user a google mail address used to send out the notification/report mails from. scheduleR uses nodemailer: https://github.com/nodemailer/nodemailer
#' @param mailer.auth.pass the password of the mailer.auth.user email
#' @param db.host character string with the name of the url where the mongo database is running (the backbone of scheduler). Defaults to localhost. Change to the IP address where you host mongo.
#' @param db.suffix character string with the name of the mongo document database where logs, tasks, users, ... of the scheduleR instance are stored.
#' @param port port where the scheduleR application runs under. Defaults to 3000.
#' @param mailer a full mailer list object if not specified through mailer.from, mailer.auth.user or mailer.auth.pass
#' @param db a full db list object if not specified through db.url and db.suffix
#' @return a list with scheduleR configuration settings which can be used by the scheduleR application
#' @examples
#' x <- scheduleR_config()
#' str(x)
#' x <- scheduleR_config(db.host = "19.19.19.19", 
#'    mailer.from = "scheduleR <computersaysno@@bnosac.be>",
#'    mailer.auth.user = "computersaysno@@bnosac.be", 
#'    mailer.auth.pass = "abc123")
#' str(x)
#' jsonlite::toJSON(x)
scheduleR_config <- function(uploadDir = "/home/scheduler/scripts",
                             errorNotificationMailAddresses,
                             mailer,
                             mailer.from = "scheduleR <computersaysno@bnosac.be>",
                             mailer.auth.user = "please.changeme@google.be",
                             mailer.auth.pass = "fillinyourgooglepwd",
                             db,
                             db.host = "localhost",
                             db.suffix = "scheduleR",
                             port = 3000L){
  default <- system.file("extdata", "user.config.json", package="RscheduleR")
  config <- jsonlite::fromJSON(default, simplifyVector = FALSE)
  config$uploadDir <- uploadDir
  if(!missing(errorNotificationMailAddresses)){
    config$errorNotificationMailAddresses <- as.list(errorNotificationMailAddresses)  
  }else{
    config$errorNotificationMailAddresses <- list()
  }
  config$mailer$from <- mailer.from
  config$mailer$options$auth$user <- mailer.auth.user
  config$mailer$options$auth$pass <- mailer.auth.pass
  config$port <- port
  config$db$url <- sprintf("mongodb://%s", db.host)
  config$db$suffix <- db.suffix
  if(!missing(mailer)){
    config$mailer <- mailer
  }
  if(!missing(db)){
    config$db <- db
  }
  class(config) <- c("scheduleR_config", "list")
  config
}



#' @title Print a scheduleR_config or save it to a file as JSON
#' @description Print a scheduleR_config or save it to a file as JSON.
#' 
#' @export 
#' @param x an object of class scheduleR_config
#' @param toJSON logical, indicating to save the scheduleR_config as JSON in a file
#' @param file path to the file where to save the config a JSON
#' @param ... other arguments, not used yet
#' @return invisible()
#' @seealso \code{\link{scheduleR_config}}
#' @examples
#' x <- scheduleR_config()
#' x
#' f <- tempfile()
#' print(x, toJSON=TRUE, file = f)
#' 
#' jsonlite::fromJSON(f, simplifyVector = FALSE)
print.scheduleR_config <- function(x, toJSON=FALSE, file=tempfile(), ...){
  if(toJSON){
    out <- jsonlite::toJSON(x, auto_unbox = TRUE, pretty = TRUE)  
    writeLines(out, con = file)
  }else{
    print.default(x)
  }
  invisible()
}
