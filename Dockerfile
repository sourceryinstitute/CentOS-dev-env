# Set an empty SDE, scripts should detect and populate with
# the current unix epoch.
ARG GCC_SDE=

# Define a image to build gcc to avoid having to
# do a bootstrap build
FROM centos:7.5.1804 AS bootstrap

ARG GCC_SDE

ENV PHASE bootstrap
ENV GCC_VER 8.2.0
ENV PACKAGES_DIR /opt
ENV GCC_PREFIX ${PACKAGES_DIR}/gcc/${GCC_VER}
ENV PKG_SRC /tmp/pkg_source
ENV SOURCE_DATE_EPOCH=${GCC_SDE:-}

WORKDIR ${PKG_SRC}
COPY ./scripts/install-rpms.sh \
     ./scripts/${PHASE}-rpms.list ./
RUN ./install-rpms.sh && rm ./install-rpms.sh

COPY ./scripts/gcc-${GCC_VER}.tar.gz.sha256 \
     ./scripts/install-gcc.sh ./
RUN ./install-gcc.sh && rm ./install-gcc.sh

COPY ./scripts/gcc-smoke-test.sh ./
RUN ./gcc-smoke-test.sh && rm ./gcc-smoke-test.sh


# This is the actual image we'll be using
# with GCC built from the other image copied in
FROM centos:7.5.1804 AS runtime

ENV PHASE runtime
ENV GCC_VER 8.2.0
ENV PACKAGES_DIR /opt
ENV GCC_PREFIX ${PACKAGES_DIR}/gcc/${GCC_VER}
ENV PKG_SRC /tmp/pkg_source

WORKDIR ${PKG_SRC}
COPY ./scripts/install-rpms.sh \
     ./scripts/runtime-rpms.list ./
RUN ./install-rpms.sh && rm ./install-rpms.sh

COPY --from=bootstrap ${PACKAGES_DIR}/gcc ${PACKAGES_DIR}/gcc
COPY --from=bootstrap /etc/ld.so.conf.d/local.conf /etc/ld.so.conf.d/local.conf
COPY ./scripts/gcc-smoke-test.sh ./
RUN ./gcc-smoke-test.sh && rm ./gcc-smoke-test.sh

ENV GIT_VER 2.19.1
ENV GIT_PREFIX ${PACKAGES_DIR}/git/${GIT_VER}

WORKDIR ${PKG_SRC}
COPY ./scripts/git-${GIT_VER}.tar.gz.sha256 \
	./scripts/install-git.sh ./
ARG GIT_SDE=
RUN ./install-git.sh && rm ./install-git.sh git-${GIT_VER}.tar.gz.sha256

ENV CMAKE_VER 3.12.3
ENV CMAKE_PREFIX ${PACKAGES_DIR}/cmake/${CMAKE_VER}

WORKDIR ${PKG_SRC}
COPY ./scripts/cmake-${CMAKE_VER}-SHA-256.txt \
     ./scripts/cmake-3.12.3-SHA-256.txt.asc \
	./scripts/install-cmake.sh ./
ARG CMAKE_SDE=
RUN ./install-cmake.sh && rm ./install-cmake.sh
