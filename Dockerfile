FROM alpine:3.11

# expose ports
EXPOSE 80/tcp
EXPOSE 443/tcp

ENV DOMAIN localhost
ENV DOCUMENT_ROOT /public

# install console tools
RUN apk add \
    inotify-tools

# install zsh
RUN apk add \
    zsh \
    zsh-vcs

# configure zsh
ADD --chown=root:root include/zshrc /etc/zsh/zshrc

# install php
RUN apk add \
    # use php7-fpm instead of php7-apache2
    php7-fpm \
    php7-bcmath \
    php7-common \
    php7-ctype \
    php7-curl \
    php7-dom \
    php7-fileinfo \
    php7-json \
    php7-mbstring \
    php7-mysqli \
    php7-openssl \
    php7-pdo \
    php7-pdo_mysql \
    php7-posix \
    php7-session \
    php7-simplexml \
    php7-tokenizer \
    php7-xml \
    php7-xmlwriter \
    php7-zip

# install xdebug
RUN apk add \
    php7-pecl-xdebug

# configure xdebug
ADD --chown=root:root include/xdebug.ini /etc/php7/conf.d/xdebug.ini

# install composer
RUN apk add \
    composer

# install nginx
RUN apk add \
    nginx

RUN mkdir -p /run/nginx/

# add nginx config
ADD --chown=root:root include/default.conf /etc/nginx/conf.d/default.conf

# install openssl
RUN apk add \
    openssl

# change php max execution time for easier debugging
RUN sed -i 's|^max_execution_time .*$|max_execution_time = 600|g' /etc/php7/php.ini

RUN mkdir /etc/ssl/nginx

# generate RSA private key
RUN openssl genrsa -out /etc/ssl/nginx/server.key 2048

# add site test page
ADD --chown=root:root include/index.php /var/www/site/index.php

# add entry point script
ADD --chown=root:root include/start.sh /start.sh

# make entry point script executable
RUN chmod +x /start.sh

# set working dir
WORKDIR /var/www/site/

ENTRYPOINT ["/start.sh"]
