#!/bin/bash
set -e

source dev-container-features-test-lib

check "libvips is installed" bash -c "dpkg -l | grep libvips"

check "FFmpeg is installed" bash -c "ffmpeg -version"
check "Poppler is installed" bash -c "pdftoppm -v"

reportResults
