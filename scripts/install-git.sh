#!/usr/bin/env bash

# Variables required in the parent environment:
#   GIT_VER:      version of GIT to fetch & build
#   PACKAGES_DIR: where to install packages
#   PKG_SRC:      staging folder for downloading and building packages
#   GIT_PREFIX:   where to install git

set -o verbose
set -o pipefail
set -o errexit
set -o errtrace

: "${PACKAGES_DIR:=/opt}"
export PACKAGES_DIR
: "${PKG_SRC:=/tmp/pkg_source}"
export PKG_SRC
: "${GCC_PREFIX:=/${PACKAGES_DIR}/gcc/${GCC_VER}}"
export PREFIX=GCC_PREFIX

# See https://reproducible-builds.org/docs/source-date-epoch/
DATE_FMT="%Y-%m-%d"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-${GIT_SDE:-}}"
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
: "${GIT_PREFIX:=/${PACKAGES_DIR}/git/${GIT_VER}}"
export PREFIX=GIT_PREFIX
umask 0022

if ! [ -d "${PKG_SRC}" ]; then
    mkdir -p "${PKG_SRC}"
fi
if [ "X$(pwd)" != "X${PKG_SRC}" ]; then
    cd "${PKG_SRC}" || exit 1
fi

curl -L -O "https://github.com/git/git/archive/v${GIT_VER}.tar.gz"

if sha256sum -c ./"git-${GIT_VER}.tar.gz.sha256" ; then
    tar -xf "v${GIT_VER}.tar.gz" -C . && rm "v${GIT_VER}.tar.gz" ./"git-${GIT_VER}.tar.gz.sha256"
    cd "${PKG_SRC}/git-${GIT_VER}" || exit 1
else
    echo 'Git package SHA256 checksum did *NOT* match expected value!' >&2
    exit 1
fi
mkdir -p "${GIT_PREFIX}"

PATH="${GCC_PREFIX}/bin:${PATH}"
export PATH
CC="$(type -P gcc)"
export CC
CXX="$(type -P g++)"
export CXX

make -j "$(nproc)" prefix="${GIT_PREFIX}" NO_GETTEXT=1 NO_TCLTK=1 NO_EXPAT=1 NO_OPENSSL=1 all
make -j "$(nproc)" prefix="${GIT_PREFIX}" NO_GETTEXT=1 NO_TCLTK=1 NO_EXPAT=1 NO_OPENSSL=1 install

cd "${PKG_SRC}" || exit 1
rm -rf "${PKG_SRC}/git-${GIT_VER}" || true

cat >> /etc/skel/.bashrc <<-EOF
	export PATH="${GIT_PREFIX}/bin:${PATH}"
EOF
