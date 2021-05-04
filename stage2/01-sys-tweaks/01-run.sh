#!/bin/bash -e

# setup scripts for readonly root image
install -m 755 files/init_resize4ro.sh	"${ROOTFS_DIR}/usr/local/sbin"
install -m 755 files/resize2fs4ro.sh	"${ROOTFS_DIR}/usr/local/sbin"

install -d				"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d"
install -m 644 files/ttyoutput.conf	"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d/"

install -m 644 files/50raspi		"${ROOTFS_DIR}/etc/apt/apt.conf.d/"

install -m 644 files/console-setup   	"${ROOTFS_DIR}/etc/default/"

install -m 755 files/rc.local		"${ROOTFS_DIR}/etc/"

install -m 755 files/ro			"${ROOTFS_DIR}/usr/local/bin"
install -m 755 files/rw			"${ROOTFS_DIR}/usr/local/bin"

# wireless LAN configuration
cat files/interfaces > "${ROOTFS_DIR}/etc/network/interfaces"

# sysfs.conf for Fango PCB
cat files/sysfs.conf > "${ROOTFS_DIR}/etc/sysfs.conf"

# load additional modules
cat files/modules > "${ROOTFS_DIR}/etc/modules"

# make shure we will always send a cleint identifier to keep the ip
echo -e '\nsend dhcp-client-identifier "Framboise-Lambic";\n' >>"${ROOTFS_DIR}/etc/dhcp/dhclient.conf"

if [ -n "${PUBKEY_SSH_FIRST_USER}" ]; then
	install -v -m 0700 -o 1000 -g 1000 -d "${ROOTFS_DIR}"/home/"${FIRST_USER_NAME}"/.ssh
	echo "${PUBKEY_SSH_FIRST_USER}" >"${ROOTFS_DIR}"/home/"${FIRST_USER_NAME}"/.ssh/authorized_keys
	chown 1000:1000 "${ROOTFS_DIR}"/home/"${FIRST_USER_NAME}"/.ssh/authorized_keys
	chmod 0600 "${ROOTFS_DIR}"/home/"${FIRST_USER_NAME}"/.ssh/authorized_keys
fi

if [ "${PUBKEY_ONLY_SSH}" = "1" ]; then
	sed -i -Ee 's/^#?[[:blank:]]*PubkeyAuthentication[[:blank:]]*no[[:blank:]]*$/PubkeyAuthentication yes/
s/^#?[[:blank:]]*PasswordAuthentication[[:blank:]]*yes[[:blank:]]*$/PasswordAuthentication no/' "${ROOTFS_DIR}"/etc/ssh/sshd_config
fi

on_chroot << EOF
systemctl disable hwclock.sh
systemctl disable nfs-common
systemctl disable rpcbind
if [ "${ENABLE_SSH}" == "1" ]; then
	systemctl enable ssh
else
	systemctl disable ssh
fi
systemctl enable webmash
systemctl enable wm4x20c
EOF

if [ "${USE_QEMU}" = "1" ]; then
	echo "enter QEMU mode"
	install -m 644 files/90-qemu.rules "${ROOTFS_DIR}/etc/udev/rules.d/"
	echo "leaving QEMU mode"
fi

on_chroot <<EOF
for GRP in input spi i2c gpio; do
	groupadd -f -r "\$GRP"
done
for GRP in adm dialout cdrom audio users sudo video games plugdev input gpio spi i2c netdev; do
  adduser $FIRST_USER_NAME \$GRP
done
EOF

on_chroot << EOF
setupcon --force --save-only -v
EOF

on_chroot << EOF
usermod --pass='*' root
EOF

rm -f "${ROOTFS_DIR}/etc/ssh/"ssh_host_*_key*


# changes for readonly image
# also use resolvconf to avoid needing a writeable /etc/resolv.conf
on_chroot << EOF
  mkdir /etc/systemd/system/systemd-random-seed.service.d
  echo -e '[Service]\nExecStartPre=/bin/echo "" >/tmp/random-seed' >/etc/systemd/system/systemd-random-seed.service.d/readonly.conf
  ln -s /tmp/random-seed /var/lib/systemd/random-seed
  rm -f /etc/resolv.conf
  ln -sf /run/resolvconf/resolv.conf /etc/resolv.conf 
EOF

# changes for Web 2.0 Mash image
install -m 644 files/99-lcd.rules "${ROOTFS_DIR}/etc/udev/rules.d/"
mkdir "${ROOTFS_DIR}/etc/systemd/system/webmash.service.d"
install -m 644 files/webmash.service.override.conf "${ROOTFS_DIR}/etc/systemd/system/webmash.service.d/override.conf"
mkdir "${ROOTFS_DIR}/etc/systemd/system/wm4x20c.service.d"
install -m 644 files/wm4x20c.service.override.conf "${ROOTFS_DIR}/etc/systemd/system/wm4x20c.service.d/override.conf"
install -m 644 files/mashctld.conf "${ROOTFS_DIR}/etc/mashctld.conf"

