FROM debian:bullseye

RUN apt-get update && \
    apt-get install -y mariadb-server mariadb-client procps && \
    rm -rf /var/lib/apt/lists/*

COPY ./script/init.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/init.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/init.sh"]
