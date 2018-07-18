#!/bin/bash -e

if [ "$#" -ne "3" ]; then
	echo "usage: ubuntu.sh HOSTNAME TARGET_DISK USER:string:KEY_STRING"
	exit 1
fi
HOSTNAME="$1"
TARGET_DISK="$2"
USERNAME="${3%%:*}"
KEY_SELECTOR="$3"

set +x

WORKDIR="$(mktemp -d --suffix=.virt-builder)"

virt-builder ubuntu-18.04 -o "$WORKDIR/image" --format raw \
	--root-password disabled \
	--timezone UTC \
	--hostname "$HOSTNAME" \
	--update --install e2fsprogs,cloud-guest-utils,sudo \
	--write /etc/sudoers.d/nopasswd:'%sudo ALL=(ALL:ALL) NOPASSWD: ALL' --chmod 0440:/etc/sudoers.d/nopasswd \
	--edit /etc/default/grub:'s/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT="console=ttyS0,115200n8"/' \
	--edit /etc/default/grub:'s/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=0/' \
	--run-command "update-grub" \
	--run-command "deluser builder && rm -rf /home/builder" \
	--run-command "adduser --disabled-password --gecos '' $USERNAME" \
	--run-command "adduser $USERNAME sudo" \
	--run-command "sed -i 's/vda1/sda1/g' /boot/grub/grub.cfg" \
	--run-command "sed -i 's/ens2/ens3/g' /etc/netplan/01-netcfg.yaml" \
	--ssh-inject "$KEY_SELECTOR" \
	--firstboot-command "growpart /dev/sda 1 && resize2fs /dev/sda1" \
	--firstboot-command "dpkg-reconfigure openssh-server"
virt-sparsify --in-place "$WORKDIR/image"
sudo dd if="$WORKDIR/image" of="$TARGET_DISK" conv=sparse

rm -rf "$WORKDIR"
