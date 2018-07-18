#!/bin/bash -e

if [ "$#" -ne "3" ]; then
	echo "usage: debian.sh HOSTNAME TARGET_DISK USER:string:KEY_STRING"
	exit 1
fi
HOSTNAME="$1"
TARGET_DISK="$2"
USERNAME="${3%%:*}"
KEY_SELECTOR="$3"

set +x

WORKDIR="$(mktemp -d --suffix=.virt-builder)"

virt-builder debian-9 -o "$WORKDIR/image" --format raw \
	--root-password disabled \
	--timezone UTC \
	--hostname "$HOSTNAME" \
	--update --install e2fsprogs,cloud-guest-utils,sudo \
	--write /usr/sbin/policy-rc.d:'exit 101' --chmod 0755:/usr/sbin/policy-rc.d \
	--write /etc/sudoers.d/nopasswd:'%sudo ALL=(ALL:ALL) NOPASSWD: ALL' --chmod 0440:/etc/sudoers.d/nopasswd \
	--write /etc/apt/sources.list.d/backports.list:'deb http://ftp.debian.org/debian stretch-backports main' \
	--append-line /etc/apt/apt.conf:'APT::Install-Recommends "false";' \
	--append-line /etc/apt/apt.conf:'APT::Install-Suggests "false";' \
	--edit /etc/default/grub:'s/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=0/' \
	--run-command "update-grub" \
	--run-command "adduser --disabled-password --gecos '' $USERNAME" \
	--run-command "adduser $USERNAME sudo" \
	--run-command "sed -i 's/vda1/sda1/g' /boot/grub/grub.cfg" \
	--run-command "sed -i 's/ens2/ens3/g' /etc/network/interfaces" \
	--ssh-inject "$KEY_SELECTOR" \
	--firstboot-command "growpart /dev/sda 1 && resize2fs /dev/sda1" \
	--firstboot-command "dpkg-reconfigure openssh-server"
virt-sparsify --in-place "$WORKDIR/image"
sudo dd if="$WORKDIR/image" of="$TARGET_DISK" conv=sparse

rm -rf "$WORKDIR"
