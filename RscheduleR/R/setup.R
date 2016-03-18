
#' @title Connect to a scheduleR instance.
#' @description Connect to a scheduleR instance.
#' 
#' @name scheduleR
#' @export scheduleR
#' @docType class
#' @param host character string with the address of the mongodb server where scheduleR is running. E.g. 127.0.0.1:27017. Change the IP address accordingly.
#' @param db character string with the name of mongodb database where scheduleR stores its data. Defaults to 'scheduleR'.
#' @param username character string with the username of the mongodb database. Use only if you have changed the Docker settings.
#' @param password character string with the password of the mongodb database. Use only if you have changed the Docker settings.
#' @section Methods:
#' \describe{
#'   \item{\code{tasks()}}{Get a list of tasks (R scripts) which are scheduled at the scheduleR instance.}
#'   \item{\code{task_delete(name)}}{Remove a task which was scheduled at the scheduleR instance. The name is the name of the task as returned by tasks()}
#'   \item{\code{task_create(file, ...)}}{Schedule an R script at a specific timepoint at the scheduleR instance.}
#' }
#' @examples
#' \dontrun{
#' x <- scheduleR(host = "localhost", port = 27017L, db = "scheduleR")
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
    .self$host <- host 
    .self$port <- port
    .self$username <- username
    .self$password <- password
    .self$db <- db
    .self$rapacheport <- rapacheport
    .self
  },
  show = function() {
    cat("Connection to a scheduleR instance:", "\n")
    cat(" host:", host, "\n")
    cat(" db:", db, "\n")
    cat(" use methods tasks, task_delete, task_create to get change tasks", "\n")
  }
)
scheduleR$methods(
  tasks = function(){
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
  }
)
scheduleR$methods(
  users = function(){
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
  users_add_guest = function(email="info@bnosac.be"){
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
      password = "L@unch321",
      email = email,
      lastName = "scheduler",
      firstName = "guest",
      "__v" = 0)
    mongo.insert.batch(mongocon, sprintf("%s.users", .self$db), list(mongo.bson.from.list(x)))
  },
  users_delete_guest = function(){
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