#!/bin/bash

echo "Set a root password"
passwd

pacman -S --needed bc reflector sudo lvm2 cryptsetup
clear

start_time="$(date -u +%s)"

echo "Setting fastest mirrors. NOTE: this might take a while... "
reflector -l 200 -n 20 -p http,https --sort rate --save /etc/pacman.d/mirrorlist &
sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf

while true; do
  read -r -p "Do you want to create a swapfile? [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    while true; do
      read -r -p "How many megabytes? (recommended 2048 or 4096 or 8192) " swap
      if [[ "$swap" =~ ^[0-9]+$ ]]; then
        break
      else
        echo "Invalid input. Please enter a valid number."
      fi
    done
    dd if=/dev/zero of=/swapfile bs=1M count="$swap" status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap defaults 0 0' | tee -a /etc/fstab
  else
    echo "No swapfile created"
  fi
  break
done
clear

while true; do
  read -r -p "Do you want to create a user? [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    while true; do
      read -r -p "Enter a username: " user
      if [[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        break
      else
        echo "Invalid username. Must start with a letter and contain only lowercase letters, numbers, and underscores."
      fi
    done
    while true; do
      read -r -p "Choose a shell (bash or zsh): " shell
      if [[ "$shell" == "bash" || "$shell" == "zsh" ]]; then
        break
      else
        echo "Invalid choice. Please enter 'bash' or 'zsh'."
      fi
    done
    useradd -m -g users -G wheel,storage,power,video,audio -s /bin/"$shell" "$user"
    echo "Enter a password"
    passwd "$user"
    sed -i '/^# %wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers
  else
    echo "No user created"
  fi
  break
done
clear

while true; do
  read -r -p "Enter your time zone (e.g. 'Europe/Amsterdam'): " tz
  if [[ -f "/usr/share/zoneinfo/$tz" ]]; then
    break
  else
    echo "Invalid timezone. Please enter a valid one."
  fi
done

ln -sf /usr/share/zoneinfo/"$tz" /etc/localtime
hwclock --systohc
timedatectl set-ntp true

# Set system locale
sed -i '/^#en_US\.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >>/etc/locale.conf

while true; do
  read -r -p "Enter a hostname: " host
  if [[ -n "$host" ]]; then
    break
  else
    echo "Invalid hostname. Please enter a valid one."
  fi
done

echo "$host" >>/etc/hostname

echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$host.localdomain $host" | tee -a /etc/hosts
clear

systemctl enable NetworkManager sshd ufw systemd-timesyncd
clear

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

while true; do
  read -r -p "Do you want to setup your system for LUKS decryption? [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    lsblk
    while true; do
      read -r -p "What partition is LUKS encrypted? (e.g. '/dev/nvme0n1p6' or '/dev/sda2'): " LUKSpart
      if [[ -b "$LUKSpart" ]]; then
        break
      else
        echo "Invalid partition. Please enter a valid block device."
      fi
    done
    lvdisplay | grep "LV Path"
    while true; do
      read -r -p "What is your LVM mapped root partition name? (e.g. '/dev/volume/root'): " LVMpart
      if [[ -b "$LVMpart" ]]; then
        break
      else
        echo "Invalid partition. Please enter a valid LVM partition."
      fi
    done
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/s/^/#/' /etc/default/grub
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=$LUKSpart:luks root=$LVMpart loglevel=3 quiet\"" | tee -a /etc/default/grub
    sed -i 's/^HOOKS=(\(.*\))/HOOKS=(\1 lvm2 encrypt)/' /etc/mkinitcpio.conf
    mkinitcpio -p linux
  else
    echo "No changes to grub or /etc/mkinitcpio.conf"
  fi
  break
done

grub-mkconfig -o /boot/grub/grub.cfg

clear

ufw enable
ufw allow ssh
ufw default deny incoming
clear

end_time="$(date -u +%s)"
elapsed="$(($end_time - $start_time))"
elapsedMinutes=$(echo "scale=2;$elapsed / 60" | bc)

echo "You are now waiting for reflector to finish optimizing mirrors"
echo "This usually takes about 7 minutes"
echo "You have been waiting for about $elapsedMinutes minutes"

wait
