#!/bin/sh
set -e

apt-get update -y && apt-get -y install --no-install-recommends pkg-config libsqlite3-dev sqlite3

rm -rf /var/lib/apt/lists/*
