#!/bin/bash
#
# arch-bootstrap: Bootstrap a base Arch Linux system.
#
# Dependencies: bash >= 4, coreutils, wget, sed, gawk, tar, gzip, chroot, xz.
# Project: https://github.com/tokland/arch-bootstrap
# Contact: Arnau Sanchez <tokland@gmail.com>
#
# Install:
#
#   $ sudo install -m 755 arch-bootstrap.sh /usr/local/bin/arch-bootstrap
#
# Some examples:
#
#   $ sudo arch-bootstrap destination
#   $ sudo arch-bootstrap -a x86_64 -r "ftp://ftp.archlinux.org" destination-x86_64 
#
# And then you can chroot to the destination directory (default user: root/root):
#
#   $ sudo chroot destination

set -e -u -o pipefail

# Output to standard error
stderr() { echo "$@" >&2; }

# Output debug message to standard error
debug() { stderr "--- $@"; }

# Extract href attribute from HTML link
extract_href() { sed -n '/<a / s/^.*<a [^>]*href="\([^\"]*\)".*$/\1/p'; }

# Simple wrapper around wget
fetch() { wget -c --passive-ftp --quiet "$@"; }

configure_pacman() {
  local DEST=$1 ARCH=$2
  debug "configure DNS and pacman"
  cp "/etc/resolv.conf" "$DEST/etc/resolv.conf"
  echo "Server = $REPO_URL/\$repo/os/$ARCH" >> "$DEST/etc/pacman.d/mirrorlist"
}

minimal_configuration() {
  local DEST=$1
  mkdir -p "$DEST/dev"
  echo "root:x:0:0:root:/root:/bin/bash" > "$DEST/etc/passwd" 
  echo 'root:$1$GT9AUpJe$oXANVIjIzcnmOpY07iaGi/:14657::::::' > "$DEST/etc/shadow"
  touch "$DEST/etc/group"
  echo "bootstrap" > "$DEST/etc/hostname"
  test -e "$DEST/etc/mtab" || echo "rootfs / rootfs rw 0 0" > "$DEST/etc/mtab"
  test -e "$DEST/dev/null" || mknod "$DEST/dev/null" c 1 3
  test -e "$DEST/dev/random" || mknod -m 0644 "$DEST/dev/random" c 1 8
  test -e "$DEST/dev/urandom" || mknod -m 0644 "$DEST/dev/urandom" c 1 9
  sed -i "s/^[[:space:]]*\(CheckSpace\)/# \1/" "$DEST/etc/pacman.conf"
  sed -i "s/^[[:space:]]*SigLevel[[:space:]]*=.*$/SigLevel = Never/" "$DEST/etc/pacman.conf"
}

check_compressed_integrity() {
  local FILEPATH=$1
  case "$FILEPATH" in
    *.gz) gunzip -t "$FILEPATH";;
    *.xz) xz -t "$FILEPATH";;
    *) debug "Error: unknown package format: $FILEPATH"
       return 1;;
  esac
}

uncompress() {
  local FILEPATH=$1 DEST=$2
  case "$FILEPATH" in
    *.gz) tar xzf "$FILEPATH" -C "$DEST";;
    *.xz) xz -dc "$FILEPATH" | tar x -C "$DEST";;
    *) debug "Error: unknown package format: $FILEPATH"
       return 1;;
  esac
}  

fetch_packages_list() {
  local ARCH=$1 REPO=$2 PACKDIR=$3 
  local LIST_HTML_FILE="$PACKDIR/core_os_$ARCH-index.html"
  if ! test -s "$LIST_HTML_FILE"; then 
    debug "fetch packages list: $REPO/"
    # Force trailing '/' needed by FTP servers.
    fetch -O "$LIST_HTML_FILE" "$REPO/" ||
      { debug "Error: cannot fetch packages list: $REPO"; return 1; }
  fi
  debug "packages HTML index: $LIST_HTML_FILE"
  local LIST=$(< "$LIST_HTML_FILE" extract_href | awk -F"/" '{print $NF}' | sort -rn)
  test "$LIST" || { debug "Error processing list file: $LIST_HTML_FILE"; return 1; }
  echo "$LIST"  
}

fetch_packages() {
  local PACKDIR=$1 BASIC_PACKAGES=$2 DEST=$3 LIST=$4
  debug "pacman package and dependencies: $BASIC_PACKAGES"
  for PACKAGE in $BASIC_PACKAGES; do
    local FILE=$(echo "$LIST" | grep -m1 "^$PACKAGE-[[:digit:]].*\(\.gz\|\.xz\)$")
    test "$FILE" || { debug "Error: cannot find package: $PACKAGE"; return 1; }
    local FILEPATH="$PACKDIR/$FILE"
    
    if ! test -e "$FILEPATH" || ! check_compressed_integrity "$FILEPATH"; then
      debug "download package: $REPO/$FILE"
      fetch -O "$FILEPATH" "$REPO/$FILE"
    fi
    debug "uncompress package: $FILEPATH"
    uncompress "$FILEPATH" "$DEST"
  done
}

install_packages() {
  local ARCH=$1 DEST=$2 BASIC_PACKAGES=$3 EXTRA_PACKAGES=$4
  debug "install packages: $BASIC_PACKAGES $EXTRA_PACKAGES"
  LC_ALL=C chroot "$DEST" /usr/bin/pacman \
    --noconfirm --arch $ARCH -Sy --force $BASIC_PACKAGES $EXTRA_PACKAGES
}


usage() {
  stderr "Usage: $(basename "$0") [-a i686|x86_64] [-r REPO_URL] DEST"
}

# Packages needed by pacman (see get-pacman-dependencies.sh)
PACMAN_PACKAGES="
  acl archlinux-keyring attr bzip2 curl expat glibc gpgme libarchive
  libassuan libgpg-error libssh2 lzo2 openssl pacman pacman-mirrorlist xz zlib
"
BASIC_PACKAGES="$PACMAN_PACKAGES filesystem"
EXTRA_PACKAGES="coreutils bash grep gawk file tar systemd"
DEFAULT_REPO_URL="http://mirrors.kernel.org/archlinux"
DEFAULT_ARCH="i686"

main() {
  # Process arguments and options
  test $# -eq 0 && set -- "-h"
  local ARCH=$DEFAULT_ARCH;
  local REPO_URL=$DEFAULT_REPO_URL
  while getopts "a:r:h" ARG; do
    case "$ARG" in
    a) ARCH=$OPTARG;;
    r) REPO_URL=$OPTARG;;
    *) usage; return 1;;
    esac
  done
  shift $(($OPTIND-1))
  test $# -eq 1 || { usage; return 1; }
  
  local DEST=$1
  local REPO="${REPO_URL%/}/core/os/$ARCH"
  debug "core repository: $REPO"
  local PACKDIR=".arch-bootstrap-packages"

  # Create directories
  debug "package directory: $PACKDIR"
  debug "destination directory: $DEST"
  mkdir -p "$PACKDIR" "$DEST"

  # Fetch packages, install and do a minimal system configuration
  LIST=$(fetch_packages_list $ARCH $REPO "$PACKDIR")
  fetch_packages "$PACKDIR" "$BASIC_PACKAGES" "$DEST" "$LIST"
  configure_pacman "$DEST" "$ARCH"
  minimal_configuration "$DEST"
  install_packages "$ARCH" "$DEST" "$BASIC_PACKAGES" "$EXTRA_PACKAGES"
  configure_pacman "$DEST" "$ARCH" # Pacman must be re-configured
  
  debug "done"
}

main "$@"
