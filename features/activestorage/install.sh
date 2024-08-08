#!/bin/sh
set -e

apt-get update -qq && \
  apt-get install --no-install-recommends -y \
    libvips \
    ffmpeg \
    poppler-utils

rm -rf /var/lib/apt/lists/*
