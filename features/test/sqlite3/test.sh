#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "Sqlite3 is installed" bash -c "sqlite3 --version"
check "Sqlite3 is in the PATH" bash -c "which sqlite3"
check "Sqlite3-dev is installed" bash -c "dpkg -l | grep sqlite3-dev"

reportResults
