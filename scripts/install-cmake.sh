#!/usr/bin/env bash

# Variables required in the parent environment:
#   CMAKE_VER:      version of CMAKE to fetch & build
#   PACKAGES_DIR: where to install packages
#   PKG_SRC:      staging folder for downloading and building packages
#   CMAKE_PREFIX:   where to install cmake

set -o verbose
set -o pipefail
set -o errexit
set -o errtrace

# See https://reproducible-builds.org/docs/source-date-epoch/
DATE_FMT="%Y-%m-%d"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-${CMAKE_SDE:-}}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date +%s)}"
export SOURCE_DATE_EPOCH
BUILD_DATE=$(date -u -d "@$SOURCE_DATE_EPOCH" "+$DATE_FMT" 2>/dev/null || date -u -r "$SOURCE_DATE_EPOCH" "+$DATE_FMT" 2>/dev/null || date -u "+$DATE_FMT")
export BUILD_DATE

echo "Build date: ${BUILD_DATE:-}"
echo "Source Date Epoch: ${SOURCE_DATE_EPOCH:-}"

: "${PACKAGES_DIR:=/opt}"
export PACKAGES_DIR
: "${PKG_SRC:=/tmp/pkg_source}"
export PKG_SRC
: "${CMAKE_PREFIX:=/${PACKAGES_DIR}/cmake/${CMAKE_VER}}"
export PREFIX=CMAKE_PREFIX
umask 0022

if ! [ -d "${PKG_SRC}" ]; then
    mkdir -p "${PKG_SRC}"
fi
if [ "X$(pwd)" != "X${PKG_SRC}" ]; then
    cd "${PKG_SRC}" || exit 1
fi

# Fetch the Kitware public GPG key. See the CMake downloads page
gpg --keyserver hkps://hkps.pool.sks-keyservers.net --recv-keys CBA23971357C2E6590D9EFD3EC8FEF3A7BFB4EDA
if gpg --list-keys --fingerprint CBA23971357C2E6590D9EFD3EC8FEF3A7BFB4EDA | \
	grep "CBA2 3971 357C 2E65 90D9  EFD3 EC8F EF3A 7BFB 4EDA" ; then
    gpg --quick-lsign-key CBA23971357C2E6590D9EFD3EC8FEF3A7BFB4EDA
else
    echo "Bad GPG fingerprint for Kitware public key. Fingerprint may be outdated." >&2
    echo "Aborting out of an abundance of caution!" >&2
    exit 1
fi

# Chain of trust: Good signature of SHA256 checksums --> SHA256 checksum matches --> asset trusted
curl -L -O "https://cmake.org/files/v${CMAKE_VER%.*}/cmake-${CMAKE_VER}-SHA-256.txt.asc"
curl -L -O "https://cmake.org/files/v${CMAKE_VER%.*}/cmake-${CMAKE_VER}-SHA-256.txt"
if gpg --verify "cmake-${CMAKE_VER}-SHA-256.txt.asc" ; then
    echo "Good signature for CMake checksum file!"
    rm "cmake-${CMAKE_VER}-SHA-256.txt.asc" || true
else
    echo "Bad signature for CMake checksum file!" >&2
    echo "The key finger-print may need updating, or there may be some other issue," >&2
    echo "Please investigate, and update as needed." >&2
    exit 1
fi
curl -L -O "https://cmake.org/files/v${CMAKE_VER%.*}/cmake-${CMAKE_VER}-Linux-x86_64.sh"
if grep "cmake-${CMAKE_VER}-Linux-x86_64.sh" | shasum -c - ; then
    echo "SHA256 cyrpotographic checksum matches for cmake-${CMAKE_VER}-Linux-x86_64.sh!"
    echo "We have verified the authenticity of the CMake installer binaries."
    rm "cmake-${CMAKE_VER}-SHA-256.txt" || true
else
    echo "Checksums appear not to match! Was there a download issue? Try again, then debug." >&2
    exit 1
fi

# Do the installation
if "./cmake-${CMAKE_VER}-Linux-x86_64.sh" --prefix="${CMAKE_PREFIX}" --skip-license --exclude-subdir ; then
    rm "./cmake-${CMAKE_VER}-Linux-x86_64.sh" || true
else
    echo 'CMake install failed!' >&2
    exit 1
fi

cat >> /etc/skel/.bashrc <<-EOF
	export PATH="${CMAKE_PREFIX}/bin:${PATH}"
EOF
