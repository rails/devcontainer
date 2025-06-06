#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "PostgreSQL client is installed" bash -c "psql --version"
check "PostgreSQL version is 14" bash -c "psql --version | grep -q 'psql (PostgreSQL) 14'"
check "libpq-dev is installed" bash -c "dpkg -l | grep libpq-dev"

reportResults
