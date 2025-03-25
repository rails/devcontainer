#!/bin/sh
set -e

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

su ${USERNAME} -c "curl -fsSL https://bun.sh/install | bash"
