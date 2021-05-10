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

# LAN configuration moved to FAT partition /boot to make it changeable from Windows machine
# this will completely ignore standard wpa_supplicant setup
mkdir "${ROOTFS_DIR}/boot/network"
cat files/interfaces > "${ROOTFS_DIR}/boot/network/interfaces"
rm -f "${ROOTFS_DIR}/etc/network/interfaces"
ln -sf /boot/network/interfaces "${ROOTFS_DIR}/etc/network/interfaces"
install files/wpa_roam.conf "${ROOTFS_DIR}/boot/network/wpa_roam.conf"

# need to mount /boot before runing networking.service 
mkdir "${ROOTFS_DIR}/etc/systemd/system/networking.service.d"
install -m 644 files/networking.service.override.conf "${ROOTFS_DIR}/etc/systemd/system/networking.service.d/override.conf"

# make sure we will always send a client identifier to keep the ip
echo -e '\nsend dhcp-client-identifier "Framboise Boon";\n' >>"${ROOTFS_DIR}/etc/dhcp/dhclient.conf"

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
  systemctl mask apt-daily.service
  systemctl mask apt-daily.timer
  systemctl mask apt-daily-upgrade.service
  systemctl mask apt-daily-upgrade.timer
  systemctl mask man-db.timer
  systemctl mask man-db.service
EOF

# changes for Web 2.0 Mash image
mkdir "${ROOTFS_DIR}/etc/systemd/system/webmash.service.d"
install -m 644 files/webmash.service.override.conf "${ROOTFS_DIR}/etc/systemd/system/webmash.service.d/override.conf"
install -m 644 files/mashctld.conf "${ROOTFS_DIR}/etc/mashctld.conf"
install -m 644 files/owfs.conf "${ROOTFS_DIR}/etc/owfs.conf"
install -m 644 files/99-*.rules "${ROOTFS_DIR}/etc/udev/rules.d/"
on_chroot << EOF
  systemctl mask wm4x20c.service
  systemctl enable owserver.socket
  systemctl mask avahi-daemon.socket
  systemctl mask avahi-daemon.service
  systemctl mask bluetooth.service
  systemctl mask hciuart.service
EOF

