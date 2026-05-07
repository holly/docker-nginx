#!/usr/bin/env bash

set -e
set -u
set -o pipefail
set -C

APP=$(basename $PWD | sed -e 's/^docker\-//')
TAG="$USER/$APP"
OPENSSL_VERSION=${OPENSSL_VERSION:-3.6.2}

docker build \
  -t ${TAG}:latest \
  --build-arg OPENSSL_VERSION=${OPENSSL_VERSION} \
  -f Dockerfile .
