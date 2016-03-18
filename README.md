RscheduleR
=================

RscheduleR is a connection interface to scheduleR (https://github.com/Bart6114/scheduleR) allowing R users from RStudio to schedule R scripts, Markdown reports and Shiny apps.

It contains

* A docker image which allows you to set up scheduleR in 1 line of code. scheduleR is an open source application to schedule R scripts, markdown reports and Shiny apps and is available at [https://github.com/Bart6114/scheduleR](https://github.com/Bart6114/scheduleR)
 
* An R package which can be installed locally which allows you to schedule R scripts at a running scheduleR instance
    + either by calling R code
    + or as an RStudio add-in which allows you to have a gui to schedule the R script from RStudio directly
    
Setup
------------------------------

**Installation of the R package.**

```
devtools::install_github("jwijffels/RscheduleR", subdir = "RscheduleR")

```

**Run the docker image which starts scheduleR.**

```
docker pull bnosac/scheduleR
docker run --name scheduler -it -p 27017:27017 -p 3000:3000 -p 3080:80 -e 'mailer_auth_user=please.changeme@google.be' -e 'mailer_auth_pass=fillinyourgooglepwd' -u root bnosac/scheduleR 

```

**Schedule a task (R script)** which runs for example every minute on every day. Tasks are specified using cron patterns. [https://en.wikipedia.org/wiki/Cron](https://en.wikipedia.org/wiki/Cron)


```
library(RscheduleR)

host <- "IP_ADDRESS_WHERE_YOU_LAUNCHED_bnosac/scheduler"
connection <- scheduleR(host = host, port = 27017L, db = "scheduleR")

## Launch an R script every minute 
myscript <- system.file("extdata", "helloworld.R", package = "scheduleR.basic")
connection$task_create(file = myscript, user = "guest", name = "mysimulation", 
  cron = "* * * * *", 
  mailOnSuccess = "computersaysyes@bnosac.be", mailOnError = "computersaysno@bnosac.be")
  
connection$tasks()

```

