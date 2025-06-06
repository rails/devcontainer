#!/bin/sh
set -e

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

if ! command -v curl > /dev/null 2>&1; then
    apt update && apt install -y curl unzip
fi

su "${USERNAME}" -c "curl -fsSL https://bun.sh/install | bash"

rm -rf /var/lib/apt/lists/*
