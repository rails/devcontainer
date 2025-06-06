#!/bin/sh
set -e

export POSTGRES_CLIENT_VERSION="${VERSION:-"15"}"

apt-get update -qq

apt-get install -y gnupg ca-certificates

client_package="postgresql-client-$POSTGRES_CLIENT_VERSION"

VERSION_EXISTS=$(apt-cache search --names-only "$client_package" | wc -l)

if [ "$VERSION_EXISTS" -ge 1 ]; then
  apt-get install --no-install-recommends -y libpq-dev "$client_package"
else
  apt-get install --no-install-recommends -y postgresql-common libpq-dev
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && apt-get install --no-install-recommends -y "$client_package"
fi

rm -rf /var/lib/apt/lists/*
