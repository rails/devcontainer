#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "libvips is installed" bash -c "dpkg -l | grep libvips"

check "FFmpeg is installed" bash -c "ffmpeg -version"
check "Poppler is installed" bash -c "pdftoppm -v"

reportResults
