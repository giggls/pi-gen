#!/bin/bash -e

echo 'APT::Install-Recommends "false";' > "${ROOTFS_DIR}/etc/apt/apt.conf.d/98norecommends"
