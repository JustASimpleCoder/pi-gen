#!/bin/bash -e

#add watne as hostname
echo "${TARGET_HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"

#update the host file
echo "127.0.1.1		${TARGET_HOSTNAME}" >> "${ROOTFS_DIR}/etc/hosts"

#disables predictable netowrk naming
ln -sf /dev/null "${ROOTFS_DIR}/etc/systemd/network/99-default.link"


on_chroot << EOF
	SUDO_USER="${FIRST_USER_NAME}" raspi-config nonint do_net_names 1
EOF
