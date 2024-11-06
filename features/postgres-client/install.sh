#!/bin/sh
set -e

export POSTGRES_CLIENT_VERSION="${VERSION:-"15"}"

apt-get update -qq

VERSION_EXISTS=$(apt-cache search --names-only postgresql-client-$POSTGRES_CLIENT_VERSION | wc -l)

if [ "$VERSION_EXISTS" -ge 1 ]; then
  apt-get install --no-install-recommends -y libpq-dev postgresql-client-$POSTGRES_CLIENT_VERSION
else
  apt-get install --no-install-recommends -y postgresql-common libpq-dev
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && apt-get install --no-install-recommends -y postgresql-client-$POSTGRES_CLIENT_VERSION
fi

rm -rf /var/lib/apt/lists/*
