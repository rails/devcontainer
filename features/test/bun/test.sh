#!/bin/bash
set -e

source dev-container-features-test-lib

check "Bun is in the PATH" bash -c "which bun"
check "Bun is installed" bash -c "bun --version"

reportResults
