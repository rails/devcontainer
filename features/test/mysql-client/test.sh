#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "Mysql client is installed" bash -c "mysql --version"
check "Mysql client is in the PATH" bash -c "which mysql"
check "libmysqlclient-dev is installed" bash -c "dpkg -l | grep libmysqlclient-dev"

reportResults
