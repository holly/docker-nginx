#!/usr/bin/env bash

set -e
set -u
set -o pipefail
set -C

APP=$(basename $PWD | sed -e 's/^docker\-//')
TAG="$USER/$APP"

docker run --env-file ./geoipupdate.env -v geoipupdate_data:/usr/share/GeoIP --rm -it ghcr.io/maxmind/geoipupdate:latest

docker run \
    -p 80:80 \
    -p 443:443 \
    -p 443:443/udp \
    --mount type=bind,source=$PWD/nginx/volume/etc/nginx/vhosts.d,target=/etc/nginx/vhosts.d \
    --mount type=bind,source=$PWD/nginx/volume/etc/nginx/njs,target=/etc/nginx/njs \
    --mount type=bind,source=$PWD/nginx/volume/var/nginx/vhosts,target=/var/nginx/vhosts \
    -v geoipupdate_data:/usr/share/GeoIP  \
    --rm -it $TAG:latest 
