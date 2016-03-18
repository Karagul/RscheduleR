
#' @title Connect to a scheduleR instance.
#' @description Connect to a scheduleR instance.
#' 
#' @export
#' @field host character string with the address of the mongodb server where scheduleR is running. E.g. 127.0.0.1:27017. Change the IP address accordingly.
#' @field db character string with the name of mongodb database where scheduleR stores its data. Defaults to 'scheduleR'.
#' @field username character string with the username of the mongodb database. Use only if you have changed the Docker settings.
#' @field password character string with the password of the mongodb database. Use only if you have changed the Docker settings.
#' @examples
#' \dontrun{
#' x <- new("scheduleR", host = "localhost", port = 27017L, db = "scheduleR")
#' x
#' x$tasks()
#' x$users()
#' x$users_delete_guest()
#' x$users_add_guest()
#' x$users()
#' myscript <- system.file("extdata", "helloworld.R", package = "RscheduleR")
#' x$task_create(file = myscript, user = "guest", name = "mysimulation", 
#'    cron = "* * * * *", 
#'    mailOnSuccess = "computersaysyes@bnosac.be", mailOnError = "computersaysno@bnosac.be")
#' x$tasks()
#' x$task_delete(name = "mysimulation")
#' }
scheduleR <- setRefClass(Class="scheduleR", 
                          fields = list(
                            host = "character", 
                            port = "integer",
                            db = "character", 
                            username = "character",
                            password = "character",
                            rapacheport = "integer"))
scheduleR$methods(
  initialize = function(host = "127.0.0.1", port = 27017L, db = "scheduleR", username = "", password = "", rapacheport = 3080L){
    "Set up the connection to the MongoDB scheduleR database"
    .self$host <- host 
    .self$port <- port
    .self$username <- username
    .self$password <- password
    .self$db <- db
    .self$rapacheport <- rapacheport
    .self
  },
  show = function() {
    "Print the scheduleR connection object"
    cat("Connection to a scheduleR instance:", "\n")
    cat(" host:", host, "\n")
    cat(" db:", db, "\n")
    cat(" use methods tasks, task_delete, task_create to get change tasks", "\n")
  },
  tasks = function(){
    "Get a data frame with all scheduled tasks"
    mongocon <- scheduleR_connect(.self)
    on.exit(mongo.destroy(mongocon))
    x <- mongo.find.all(mongocon, sprintf("%s.tasks", .self$db), query='{}', mongo.oid2character=TRUE)
    x <- lapply(x, FUN=function(x){
      data.frame(x[c("_id", "name", "description", "scriptOriginalFilename", "enabled", "user", "created", "arguments", "cron", "ignoreLock")],
                 check.names = FALSE, stringsAsFactors = FALSE)
    })
    x <- do.call(rbind, x)
    rownames(x) <- NULL
    x
  },
  task_delete = function(name){
    "Delete a task with a certain name"
    x <- .self$tasks()
    if(!name %in% x[["name"]]){
      stop(sprintf("Task '%s' is not available in the tasks registered at scheduleR, possible tasks are %s", name,
                   paste(x[["name"]], collapse=", ")))
    }
    mongocon <- scheduleR_connect(.self)
    on.exit(mongo.destroy(mongocon))
    mongo.remove(mongocon, sprintf("%s.tasks", .self$db), criteria = list(name = name))
  },
  task_create = function(file, 
                         name = "task_identifier", 
                         description = "R script description", 
                         cron = "* * * * *", 
                         user, 
                         arguments="", mailOnSuccess="", mailOnError="",
                         ignoreLock=FALSE, enabled=TRUE, debug=FALSE){
    "Create a specific task which will be run using a specific cron schedule. 
    Give the path the the R script, the name of the task, a description and when it has to be run. 
    The task will be run by the user you provided. 
    Optionally set emails which to send log messages to in case of success or failure."
    x <- .self$users()
    if(!user %in% x[["username"]]){
      stop(sprintf("User '%s' is not registered at scheduleR, possible users are %s", user,
                   paste(x[["username"]], collapse=", ")))
    }
    stopifnot(file.exists(file))
    mongocon <- scheduleR_connect(.self)
    on.exit(mongo.destroy(mongocon))
    input <- list()
    input$name <- name
    input$description <- description
    input$cron <- cron
    input$user <- as.character(x[["_id"]][which(x[["username"]] == user)])
    input$arguments <- arguments
    input$created <- Sys.time()
    input$scriptOriginalFilename <- basename(file)
    input$scriptNewFilename <- basename(file)
    input$mailOnSuccess <- list()
    if(mailOnSuccess[1] != ""){
      input$mailOnSuccess <- list(mailOnSuccess)
    }
    input$mailOnError <- list()
    if(mailOnError[1] != ""){
      input$mailOnError <- list(mailOnError)
    }
    input$ignoreLock <- ignoreLock
    input$enabled <- enabled
    input[["__v"]] <- 0
    
    ## upload the file with the RApache web service to the server
    x <- httr::POST(sprintf("%s:%s/brew/upload.R", .self$host, .self$rapacheport), 
                    body = list(rscriptfile = httr::upload_file(file)))
    x <- httr::content(x)
    if(debug){
      print(jsonlite::fromJSON(x))
    }
    ## insert the scheduler in the database
    mongo.insert.batch(mongocon, sprintf("%s.tasks", .self$db), list(mongo.bson.from.list(input)))
  },
  users = function(){
    "Get a data frame with all users of scheduleR"
    mongocon <- scheduleR_connect(.self)
    on.exit(mongo.destroy(mongocon))
    x <- mongo.find.all(mongocon, sprintf("%s.users", .self$db), query='{}', mongo.oid2character=TRUE)
    x <- lapply(x, FUN=function(x){
      data.frame(x[c("_id", "username", "displayName", "firstName", "lastName", "email", "created")],
                 check.names = FALSE, stringsAsFactors = FALSE)
    })
    x <- do.call(rbind, x)
    rownames(x) <- NULL
    x
  },
  users_add_guest = function(email="info@bnosac.be", password = "L@unch321"){
    "Add a guest user - guest user has username 'guest', password 'L@unch321' and the email address you provide"
    mongocon <- scheduleR_connect(.self)
    on.exit(mongo.destroy(mongocon))
    x <- .self$users()
    if(any("guest" %in% x$username)){
      stop("Username 'guest' already exists, you can't create it again at scheduleR")
    }
    x <- list(
      displayName = "www.bnosac.be",
      provider = "local",
      username = "guest",
      created = Sys.time(),
      roles = list("user"),
      password = password,
      email = email,
      lastName = "scheduler",
      firstName = "guest",
      "__v" = 0)
    mongo.insert.batch(mongocon, sprintf("%s.users", .self$db), list(mongo.bson.from.list(x)))
  },
  users_delete_guest = function(){
    "Delete the guest user"
    mongocon <- scheduleR_connect(.self)
    on.exit(mongo.destroy(mongocon))
    mongo.remove(mongocon, sprintf("%s.users", .self$db), criteria = list(username = "guest"))
  }
)



scheduleR_connect <- function(x){
  mongocon <- mongo.create(host = sprintf("%s:%s", x$host, x$port), 
                           db = x$db,
                           username = x$username,
                           password = x$password)
  mongocon
}

scheduleR_users_add_guest <- function(host = "localhost", port = 27017L, db = "scheduleR", ...){
  x <- new("scheduleR", host = host, port = port, db = db)
  x$users_add_guest(...)
}