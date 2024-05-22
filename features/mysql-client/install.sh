#!/bin/sh
set -e

apt-get update -y && apt-get -y install --no-install-recommends default-libmysqlclient-dev

rm -rf /var/lib/apt/lists/*
