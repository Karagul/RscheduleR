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

**Get and run the docker image which starts scheduleR.**

```
docker pull bnosac/scheduleR
docker run -d -p 27017:27017 -p 3000:3000 -p 3080:80 -e 'mailer_auth_user=please.changeme@google.be' -e 'mailer_auth_pass=fillinyourgooglepwd' -u root bnosac/scheduleR 
```

*scheduleR is now accessible at port 3000*, so go to IP_ADDRESS_WHERE_YOU_LAUNCHED_IT:3000 to see it.

**Schedule a task (R script)** which runs for example every minute on every day. Tasks are specified using cron patterns and allow you do schedule dayly, hourly, monthly, ... see [https://en.wikipedia.org/wiki/Cron](https://en.wikipedia.org/wiki/Cron) for more info.


```
library(RscheduleR)

host <- "IP_ADDRESS_WHERE_YOU_LAUNCHED_bnosac/scheduler"
connection <- new("scheduleR", host = host, port = 27017L, db = "scheduleR")

## Launch an R script every minute 
myscript <- system.file("extdata", "helloworld.R", package = "scheduleR.basic")
connection$task_create(file = myscript, user = "guest", name = "mysimulation", 
  cron = "* * * * *", 
  mailOnSuccess = "computersaysyes@bnosac.be", mailOnError = "computersaysno@bnosac.be")
  
connection$tasks()
```


More background
------------------------------

[scheduleR](https://github.com/Bart6114/scheduleR) is basically a node application with a MongoDB as backend. The RscheduleR R package communicates with the MongoDB backend and allows to upload scripts through an upload webservice implemented with RApache.
Mark that when the scheduleR instance is launched with docker, the MongoDB is launched, the RApache webservice and scheduleR itself. 

When starting the dockerised scheduleR application, a guest user is created with username 'guest' and password 'L@unch321', you might want to go to YOURIP:3000 to change that. When launching scheduleR with docker, set up **mailer_auth_user** and **mailer_auth_pass** as shown above to your own google email address. This will be used to send out mails from scheduleR indicating if your script has failed or succeeded. 

Mark that:

* The MongoDB is accessible at port 27017 in the example above
* The RApache upload functionality is available at YOURIP:3080/brew/upload.R in the example above  
* scheduleR itself runs at port 3000

When uploading scripts to the scheduleR instance, these are put at /home/scheduler/scripts.

If you want the MongoDB to be persistent as well as the scripts. You probably want to launch scheduleR as follows. This will make sure the MongoDB is persisted at /opt/scheduler/mongo and the R scripts at /opt/scheduler/scripts.

```
docker run --name scheduler -d -p 27017:27017 -p 3000:3000 -p 3080:80 -e 'mailer_auth_user=please.changeme@google.be' -e 'mailer_auth_pass=fillinyourgooglepwd' -v /opt/scheduler/mongo:/data/db -v /opt/scheduler/scripts:/home/scheduler/scripts -u root bnosac/scheduleR 
```

MongoDB runs by default without username/password. If you need this, you can contact [http://www.bnosac.be/contact](http://www.bnosac.be/contact)

