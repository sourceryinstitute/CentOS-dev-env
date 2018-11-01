#!/usr/bin/env bash

# Install build or runtime RPMs
set -o verbose
set -o pipefail
set -o errexit
set -o errtrace

umask 0022

# See if the default image ships with keys, and also, see how yum
# has fetched and updated keys
rpm -qa --qf '%{VERSION}-%{RELEASE} %{SUMMARY}\n' gpg-pubkey*
# Apply security updates first
yum update -y --security
rpm -qa --qf '%{VERSION}-%{RELEASE} %{SUMMARY}\n' gpg-pubkey*
# Get the gcc-7 toolchain to skip bootstrapping
if [ "X${PHASE}" = "Xbootstrap" ]; then
    yum install -y centos-release-scl
fi

# Select the build or runime lit of RPMS
cat "${PHASE:-runtime}-rpms.list" | xargs yum install -y && \
    rm "${PHASE:-runtime}-rpms.list"
rpm -qa --qf '%{VERSION}-%{RELEASE} %{SUMMARY}\n' gpg-pubkey*
# Cleanup
yum clean all
rm -rf /var/cache/yum || true
