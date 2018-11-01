#!/usr/bin/env bash

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

export PATH="${GCC_PREFIX}/bin:${PATH}"

gcc --version
gfortran --version
g++ --version

cat /etc/ld.so.conf.d/local.conf
ldconfig

cat > smoke_test.c <<EOF
    int main(){return 0;};
EOF
gcc -o smoke_test{,.c}
if ! ./smoke_test; then
   echo "Smoke test of GCC ${GCC_VER} failed!" >&2
   exit 1
fi
rm smoke_test*
cat > smoke_test.f90 <<EOF
    print*, "Hello world"; end
EOF
gfortran -o smoke_test{,.f90}
if ! ./smoke_test | grep "Hello world" ; then
   echo "Smoke test of GFortran ${GCC_VER} failed!" >&2
   exit 1
fi
