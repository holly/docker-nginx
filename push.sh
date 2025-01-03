#!/usr/bin/env bash

set -e
set -u
set -o pipefail
set -C

APP=$(basename $PWD | sed -e 's/^docker\-//')
TAG="$USER/$APP"
docker push ${TAG}:latest
