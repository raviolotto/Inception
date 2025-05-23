FROM debian:bullseye

RUN apt-get upgrade -y && apt-get update -y

RUN apt-get install nginx openssl -y

RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/C=IT/ST=None/L=None/O=42/OU=student/CN=${DOMAIN_NAME}"

COPY ./conf/nginx.conf /etc/nginx/conf.d/default.conf


EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]