#!/bin/sh
set -e

apt-get update -y && apt-get -y install --no-install-recommends default-mysql-client

rm -rf /var/lib/apt/lists/*
