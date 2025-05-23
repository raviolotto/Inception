FROM debian:bullseye

RUN apt-get update -y && apt-get upgrade -y

RUN apt-get install php-fpm -y && apt-get install php-mysql -y && apt-get install curl -y

COPY ./script/script.sh /

RUN chmod 777 /script.sh


CMD [ "/script.sh" ]