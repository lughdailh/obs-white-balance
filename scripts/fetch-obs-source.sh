#!/bin/sh
set -eu
version="${1:-30.2.3}"
destination="${2:-.deps/obs-studio}"
if [ ! -f "$destination/libobs/obs-module.h" ]; then
  mkdir -p "$(dirname "$destination")"
  git clone --depth 1 --branch "$version" \
    https://github.com/obsproject/obs-studio.git "$destination"
fi
printf '%s\n' "$destination"
