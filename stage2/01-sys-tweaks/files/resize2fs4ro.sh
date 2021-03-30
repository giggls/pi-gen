#!/bin/bash

mount -t proc none /proc

# device names are hardcoded here for now because
# findmount does not seem to work
mount -o remount,rw /dev/mmcblk0p2 /
mount /dev/mmcblk0p1 /boot

echo "resizing root filesystem:"
resize2fs /dev/mmcblk0p2
echo "done."

echo -n "setting /boot/cmdline.txt to ro mode... "
sed -i -e 's/ init=[^ ]\+//g' -e 's/rootwait/rootwait fastboot noswap ro/g' /boot/cmdline.txt
echo "done."

echo -n "setting /etc/fstab to ro mode... "
sed -i -e 's|\([[:space:]]/[[:space:]].*\)defaults|\1defaults,ro|g' -e 's|\([[:space:]]/boot[[:space:]].*\)defaults|\1defaults,ro|g' /etc/fstab
echo "done."

# these are basically the commands from regenerate_ssh_host_keys.service
# We can not run this in its usual way as we have a readonly image
dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096
rm -f -v /etc/ssh/ssh_host_*_key*
ssh-keygen -A -v

# remove the setup script incuding this one
rm -f /usr/local/sbin/init_resize4ro.sh
rm -f /usr/local/sbin/resize2fs4ro.sh

echo -n "rebooting into readonly mode... "

umount /boot
mount -o remount,ro /dev/mmcblk0p2 /
sync

echo b > /proc/sysrq-trigger

echo "done."
sleep 5
exit 0
