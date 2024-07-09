#!/bin/bash

printf "\n\nStarting PHP 8.1 daemon...\n\n"
/usr/sbin/php-fpm8.1 --daemonize

printf "Starting Nginx...\n\n"
set -e

if [[ "$1" == -* ]]; then
    set -- nginx -g daemon off; "$@"
fi

exec "$@"