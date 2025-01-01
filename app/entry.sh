#!/usr/bin/env bash

set -e
set -u
set -o pipefail
set -C

NGINX_CMD=/usr/sbin/nginx
SLEEP_INTERVAL=86400
trap "$NGINX_CMD -s stop; sleep 3; echo nginx stopped." 1 2 3 15

{
    while true; do
        sleep $SLEEP_INTERVAL;
        $NGINX_CMD -s reload
    done
} &

echo "nginx start..."
$NGINX_CMD -g "daemon off;"
