#!/bin/sh
set -e -u -o pipefail

shared_dependencies() {
  local EXECUTABLE=$1
  for PACKAGE in $(ldd "$EXECUTABLE" | grep "=> /" | awk '{print $3}'); do 
    LC_ALL=c pacman -Qo $PACKAGE
  done | awk '{print $5}'
}

pkgbuild_dependencies() {
  local PKGBUILD=$1
  local EXCLUDE=$2
  source "$PKGBUILD"
  for DEPEND in ${depends[@]}; do
    echo "$DEPEND" | sed "s/[>=<].*$//"
  done | grep -v "$EXCLUDE"
}

main() {
  path="pacman-PKGBUILD"
  curl "https://git.archlinux.org/svntogit/packages.git/plain/trunk/PKGBUILD?h=packages/pacman" > $path
  {
    shared_dependencies "/usr/bin/pacman"
    pkgbuild_dependencies "$path" "bash"
  } | sort -u | xargs
}

main
