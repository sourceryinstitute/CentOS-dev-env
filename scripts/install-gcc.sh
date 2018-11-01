#!/usr/bin/env bash

# Variables required in the parent environment:
#   GCC_VER: version of GCC to fetch & build
#   PACKAGES_DIR: where to install packages
#   PKG_SRC:      staging folder for downloading and building packages

# shellcheck disable=SC1091
. /opt/rh/devtoolset-7/enable

set -o verbose
set -o pipefail
set -o errexit
set -o errtrace

# See https://reproducible-builds.org/docs/source-date-epoch/
DATE_FMT="%Y-%m-%d"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-${GCC_SDE:-}}"
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
: "${GCC_PREFIX:=/${PACKAGES_DIR}/gcc/${GCC_VER}}"
export PREFIX=GCC_PREFIX
umask 0022

if ! [ -d "${PKG_SRC}" ]; then
    mkdir -p "${PKG_SRC}"
fi
if [ "X$(pwd)" != "X${PKG_SRC}" ]; then
    cd "${PKG_SRC}" || exit 1
fi

curl -L -O "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.gz"
curl -L -O "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.gz.sig"
curl -L -O "https://ftp.gnu.org/gnu/gnu-keyring.gpg"
set +o pipefail
if gpg --verify --keyring ./gnu-keyring.gpg "gcc-${GCC_VER}.tar.gz.sig" 2>&1 | grep "[Gg]ood signature" ; then
    rm "gcc-${GCC_VER}.tar.gz.sig"
else
    echo "Bad signature for gcc-${GCC_VER}.tar.gz!" >&2
    exit 1
fi
set -o pipefail
if sha256sum -c ./"gcc-${GCC_VER}.tar.gz.sha256" ; then
    tar -xf "gcc-${GCC_VER}.tar.gz" -C . && rm "gcc-${GCC_VER}.tar.gz" ./"gcc-${GCC_VER}.tar.gz.sha256"
    cd "${PKG_SRC}/gcc-${GCC_VER}" || exit 1
else
    echo 'GCC package SHA256 checksum did *NOT* match expected value!' >&2
    exit 1
fi
./contrib/download_prerequisites
mkdir -p "${PKG_SRC}/gcc-build"
cd "${PKG_SRC}/gcc-build" || exit 1
mkdir -p "${GCC_PREFIX}"
# Disable bootstrap only works when GCC building gcc is one major version behind or less
"../gcc-${GCC_VER}/configure" --prefix="${GCC_PREFIX}" \
       --disable-bootstrap \
       --disable-multilib \
       --enable-languages=c,c++,fortran,jit,lto \
       --enable-checking=release \
       --disable-werror \
       --disable-nls \
       --enable-host-shared \
       --with-pic
make -j "$(nproc)"
make install-strip -j "$(nproc)" || exit 1

cd "${PKG_SRC}" || exit 1
rm -rf "${PKG_SRC}/gcc-build" || true
rm -rf "${PKG_SRC}/gcc-${GCC_VER}" || true

cat >> /etc/ld.so.conf.d/local.conf <<-EOF
${GCC_PREFIX}/lib64
${GCC_PREFIX}/lib
${GCC_PREFIX}/lib/gcc/x86_64-pc-linux-gnu/${GCC_VER}
${GCC_PREFIX}/libexec/gcc/x86_64-pc-linux-gnu/${GCC_VER}
EOF

cat /etc/ld.so.conf.d/local.conf
ldconfig
