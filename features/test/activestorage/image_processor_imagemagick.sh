#!/bin/bash
set -e

source dev-container-features-test-lib

check "imagemagick is installed" bash -c "convert --version"
check "FFmpeg is installed" bash -c "ffmpeg -version"
check "Poppler is installed" bash -c "pdftoppm -v"

reportResults
