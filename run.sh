#!/usr/bin/env bash

set -e
set -u
set -o pipefail
set -C

APP=$(basename $PWD | sed -e 's/^docker\-//')
TAG="$USER/$APP"

docker run \
    -p 80:80 \
    -p 443:443 \
    -p 443:443/udp \
    -v /data/geoipupdate/GeoIP:/usr/share/GeoIP \
    --rm -it $TAG:latest 
