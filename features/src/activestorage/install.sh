#!/bin/sh
set -e

if [ "$VARIANTPROCESSOR" = "mini_magick" ]; then
  IMAGE_PROCESSOR="imagemagick"
else
  IMAGE_PROCESSOR="libvips"
fi

apt-get update -qq && \
  apt-get install --no-install-recommends -y \
    $IMAGE_PROCESSOR \
    ffmpeg \
    poppler-utils

rm -rf /var/lib/apt/lists/*
