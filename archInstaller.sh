#!/bin/bash

lsblk
read -r -p "Enter your main drive (e.g. '/dev/sda') " drive

echo "Please create 2 partitions"
echo "Partition 1 should be an EFI system boot partition of 1GB."
echo "Partition 2 should be Linux filesystem, this will be root"
echo "The 2nd partition can take up the full disk or only a part of it (this is up to you, but it is recommended to be at least 20GB)"
echo "Delete or keep any other existing partitions (this guide will not help with dualbooting.)"

sleep 3
echo "Press any key to continue..."
read -n 1 -s -r

(
  cfdisk "$drive"
)

clear
lsblk

read -r -p "Enter EFI system partition (e.g. '/dev/sda1') " EFIpart
read -r -p "Enter root partition (e.g. '/dev/sda2') " rootPART

mkfs.fat -F32 "$EFIpart"

read -r -p "Do you want to setup a LUKS encrypted partition? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  clear
  cryptsetup luksFormat "$rootPART"
  cryptsetup open --type luks "$rootPART" cryptlvm
  pvcreate /dev/mapper/cryptlvm
  vgcreate volume /dev/mapper/cryptlvm
  lvcreate -l 100%FREE volume -n root
  mkfs.ext4 /dev/volume/root
  mount /dev/volume/root /mnt
else
  mkfs.ext4 "$rootPART"
  mount "$rootPART" /mnt
fi

mount -m "$EFIpart" /mnt/boot

read -r -p "Do you have a Intel or AMD cpu? ['intel'/'amd'] " cpu
if [[ "$cpu" == amd ]]; then
  pacstrap -K /mnt base base-devel cryptsetup dosfstools efibootmgr fuse3 git grub linux linux-firmware linux-headers lvm2 man man-db mtools networkmanager openssh pacman-contrib reflector sudo ufw zsh neovim btop fastfetch fd fzf gdu tree wget curl amd-ucode
else
  pacstrap -K /mnt base base-devel cryptsetup dosfstools efibootmgr fuse3 git grub linux linux-firmware linux-headers lvm2 man man-db mtools networkmanager openssh pacman-contrib reflector sudo ufw zsh neovim btop fastfetch fd fzf gdu tree wget curl intel-media-driver intel-ucode
fi

genfstab -U /mnt >>/mnt/etc/fstab

echo "end of disk setup, continuing to chrooting"

wget -L https://raw.githubusercontent.com/mango7006/installer/refs/heads/main/postChroot.sh
cp postChroot.sh /mnt
chmod +x /mnt/postChroot.sh
arch-chroot /mnt /postChroot.sh
