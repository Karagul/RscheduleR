######################################################
## scheduleR (https://github.com/Bart6114/scheduleR) docker application 
##  extended for working from it from R directly using package RscheduleR
##  which can be installed from http://www.datatailor.be/rcube
##
######################################################

FROM ubuntu:14.04
MAINTAINER "bnosac" info@bnosac.be

RUN useradd scheduler \
    && mkdir /home/scheduler \
    && chown scheduler:scheduler /home/scheduler \
    && addgroup scheduler staff
	
WORKDIR "/home/scheduler"

######################################################
## MongoDB - database backend for scheduleR
##
######################################################
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927  \
    && echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list \
    && apt-get update -qq \
    && apt-get install -y mongodb-org  \
    && mkdir -p /data/db
    
######################################################
## R installation
##
######################################################
RUN cd /home/scheduler \
    && apt-get update -qq \
    && apt-get install -y software-properties-common \
    && add-apt-repository 'deb http://cran.rstudio.com/bin/linux/ubuntu trusty/' \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9 \
    && apt-get update -qq \
    && apt-get install -y r-base r-base-dev r-recommended

######################################################
## scheduleR installation
##
######################################################
RUN cd /home/scheduler \
    && apt-get update -qq \
    && apt-get install -y git curl \
    && apt-get install -y --no-install-recommends nodejs npm nodejs-legacy \
    && apt-get install -y --no-install-recommends liberror-perl \
    && apt-get install -y pandoc \
    && Rscript -e "install.packages(c('knitr', 'rmarkdown'), repos='http://cran.rstudio.com/')" \
    && git clone https://github.com/jwijffels/scheduleR.git
    
RUN cd /home/scheduler \
    && mkdir scripts \
    && npm install --global scheduleR
    
######################################################
## RApache installation (to upload an R script)
##
######################################################
RUN cd /home/scheduler \
    && apt-get update -qq \
    && apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:opencpu/opencpu-1.5 \
    && apt-get update -qq \
    && apt-get install -y libapache2-mod-r-base

RUN Rscript -e "install.packages(c('brew', 'jsonlite'), repos='http://cran.rstudio.com/')"
RUN mkdir /var/www/html/brew
RUN echo "<Directory /var/www/html/brew>" >> /etc/apache2/apache2.conf \
    && echo "SetHandler r-script" >> /etc/apache2/apache2.conf  \
    && echo "RHandler brew::brew" >> /etc/apache2/apache2.conf  \
    && echo "</Directory>" >> /etc/apache2/apache2.conf

## set up webservice to be able to upload a file
RUN echo "<%"  >> /var/www/html/brew/upload.R \
    && echo "destination <- file.path('/home/scheduler/scripts', FILES[['rscriptfile']][['name']])" >> /var/www/html/brew/upload.R \
    && echo "invisible(file.copy(FILES[['rscriptfile']][['tmp_name']], destination, overwrite=TRUE))" >> /var/www/html/brew/upload.R \
    && echo "x <- file.info(destination)" >> /var/www/html/brew/upload.R \
    && echo "x[['mode']] <- as.integer(x[['mode']])" >> /var/www/html/brew/upload.R \
    && echo "cat(jsonlite::toJSON(x))" >> /var/www/html/brew/upload.R \
    && echo "invisible(setStatus(status=200L))" >> /var/www/html/brew/upload.R \
    && echo "%>" >> /var/www/html/brew/upload.R

######################################################
## scheduleR setup config
##
######################################################
ENV mailer_auth_user=please.changeme@google.be
ENV mailer_auth_pass=fillinyourgooglepwd

RUN apt-get install -y libcurl4-openssl-dev
RUN Rscript -e "install.packages(c('rmongodb', 'jsonlite', 'httr'), repos='http://cran.rstudio.com/')" \
    && Rscript -e "install.packages('RscheduleR', repos = 'http://www.datatailor.be/rcube', type = 'source')"

RUN Rscript -e "print(RscheduleR::scheduleR_config(uploadDir = '/home/scheduler/scripts', mailer.from = 'scheduleR <noreply@bnosac.be>', mailer.auth.user = Sys.getenv('mailer_auth_user'), mailer.auth.pass = Sys.getenv('mailer_auth_pass'), db.host = 'localhost'), toJSON=TRUE, file = '/usr/local/lib/node_modules/scheduler-for-r/user.config.json')" 
RUN cat /usr/local/lib/node_modules/scheduler-for-r/user.config.json

######################################################
## Expose ports of scheduleR, RApache and MongoDB
##   launch services and make sure www-data has rights to write to /home/scheduler/scripts
## 
######################################################
EXPOSE 3000
EXPOSE 80
EXPOSE 27017

CMD cat /usr/local/lib/node_modules/scheduler-for-r/user.config.json \
    && chown -R www-data:www-data /home/scheduler/scripts \
    && chmod -R u+rX /home/scheduler/scripts \
    && mongod --fork --logpath /var/log/mongod.log \
    && service apache2 restart \
    && mkdir -p /home/scheduler/scripts \
    && Rscript -e "print(RscheduleR::scheduleR_config(uploadDir = '/home/scheduler/scripts', mailer.from = 'scheduleR <noreply@bnosac.be>', mailer.auth.user = Sys.getenv('mailer_auth_user'), mailer.auth.pass = Sys.getenv('mailer_auth_pass'), db.host = 'localhost'), toJSON=TRUE, file = '/usr/local/lib/node_modules/scheduler-for-r/user.config.json')" \
    && cd /usr/local/lib \
    && Rscript -e "try(RscheduleR:::scheduleR_users_add_guest(email = Sys.getenv('mailer_auth_user')))" \
    && exec npm start scheduler-for-r

