#!/bin/sh

echo ""
echo "Start container web server..."

echo "domain: $DOMAIN"
echo "document root: $DOCUMENT_ROOT"

# check if we should expose nginx to host
if [ -d /docker/etc/ ];
then
    echo "Expose nginx to host..."
    sleep 3

    # check if config backup exists
    if [ ! -d /etc/nginx.bak/ ];
    then
        # create config backup
        echo "Expose nginx to host - backup container config"
        cp -r /etc/nginx/ /etc/nginx.bak/
    fi

    # check if config exists on host
    if [ -z "$(ls -A /docker/etc/nginx/ 2> /dev/null)" ];
    then
        # config doesn't exist on host
        echo "Expose nginx to host - no host config"

        # check if config backup exists
        if [ -d /etc/nginx.bak/ ];
        then
            # restore config from backup
            echo "Expose nginx to host - restore config from backup"
            rm /etc/nginx/ 2> /dev/null
            cp -r /etc/nginx.bak/ /etc/nginx/
        fi

        # copy config to host
        echo "Expose nginx to host - copy config to host"
        cp -r /etc/nginx/ /docker/etc/
    else
        echo "Expose nginx to host - config exists on host"
    fi

    # create symbolic link so host config is used
    echo "Expose nginx to host - create symlink"
    rm -rf /etc/nginx/ 2> /dev/null
    ln -s /docker/etc/nginx /etc/nginx

    echo "Expose nginx to host - OK"
fi

if [ ! -e /etc/ssl/nginx/$DOMAIN.pem ];
then
    echo "Generate self-signed SSL certificate for $DOMAIN..."

    # generate self-signed SSL certificate
    openssl req -new -x509 -key /etc/ssl/nginx/server.key -out /etc/ssl/nginx/$DOMAIN.pem -days 3650 -subj /CN=$DOMAIN

    # use SSL certificate
    sed -i "s|ssl_certificate .*|ssl_certificate /etc/ssl/nginx/$DOMAIN.pem;|g" /etc/nginx/conf.d/default.conf

    echo "Generate self-signed SSL certificate for $DOMAIN - OK"
fi

echo "Configure nginx for domain..."

# set document root dir
sed -i "s|root /var/www/site;|root /var/www/site$DOCUMENT_ROOT;|g" /etc/nginx/conf.d/default.conf

sed -i "s|server_name localhost;|server_name $DOMAIN;|g" /etc/nginx/conf.d/default.conf

echo "Configure nginx for domain - OK"

# check if we should expose php to host
if [ -d /docker/etc/ ];
then
    echo "Expose php to host..."
    sleep 3

    # check if config backup exists
    if [ ! -d /etc/php7.bak/ ];
    then
        # create config backup
        echo "Expose php to host - backup container config"
        cp -r /etc/php7/ /etc/php7.bak/
    fi

    # check if php config exists on host
    if [ -z "$(ls -A /docker/etc/php7/ 2> /dev/null)" ];
    then
        # config doesn't exist on host
        echo "Expose php to host - no host config"

        # check if config backup exists
        if [ -d /etc/php7.bak/ ];
        then
            # restore config from backup
            echo "Expose php to host - restore config from backup"
            rm /etc/php7/ 2> /dev/null
            cp -r /etc/php7.bak/ /etc/php7/
        fi

        # copy config to host
        echo "Expose php to host - copy config to host"
        cp -r /etc/php7/ /docker/etc/
    else
        echo "Expose php to host - config exists on host"
    fi

    # create symbolic link so host config is used
    echo "Expose php to host - create symlink"
    rm -rf /etc/php7/ 2> /dev/null
    ln -s /docker/etc/php7 /etc/php7

    echo "Expose php to host - OK"
fi

# clean xdebug log file
truncate -s 0 /var/log/nginx/xdebug.log 2> /dev/null

# allow xdebug to write to it
chmod 666 /var/log/nginx/xdebug.log 2> /dev/null

# start php-fpm
php-fpm7

# sleep
sleep 2

# check if php-fpm is running
if pgrep -x php-fpm7 > /dev/null
then
    echo "Start php-fpm - OK"
else
    echo "Start php-fpm - FAILED"
    exit
fi

echo "-------------------------------------------------------"

# start nginx
nginx

# sleep
sleep 2

# check if nginx is running
if pgrep nginx > /dev/null
then
    echo "Start container web server - OK - ready for connections"
else
    echo "Start container web server - FAILED"
    exit
fi

echo "-------------------------------------------------------"

stop_container()
{
    echo ""
    echo "Stop container web server... - received SIGTERM signal"
    echo "Stop container web server - OK"
    exit
}

# catch termination signals
# https://unix.stackexchange.com/questions/317492/list-of-kill-signals
trap stop_container SIGTERM

restart_processes()
{
    sleep 0.5

    # test php-fpm config
    if php-fpm7 -t
    then
        # restart php-fpm
        echo "Restart php-fpm..."
        httpd -k restart

        # check if php-fpm is running
        if pgrep -x php-fpm7 > /dev/null
        then
            echo "Restart php-fpm - OK"
        else
            echo "Restart php-fpm - FAILED"
        fi
    else
        echo "Restart php-fpm - FAILED - syntax error"
    fi

    # test nginx config
    if nginx -t
    then
        # restart nginx
        echo "Restart nginx..."
        nginx -s reload

        # check if nginx is running
        if pgrep nginx > /dev/null
        then
            echo "Restart nginx - OK"
        else
            echo "Restart nginx - FAILED"
        fi
    else
        echo "Restart nginx - FAILED - syntax error"
    fi
}

# infinite loop, will only stop on termination signal
while true; do
    # restart nginx and php-fpm if any file in /etc/nginx or /etc/php7 changes
    inotifywait --quiet --event modify,create,delete --timeout 3 --recursive /etc/nginx/ /etc/php7/ && restart_processes
done
