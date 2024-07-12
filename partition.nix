#!/bin/bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check for arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <disk> <encryption-key>"
    exit 1
fi

DISK=$1
KEY=$2

# Wipe disk
sgdisk -Z "$DISK"

# Partition the disk
parted --script "$DISK" mklabel gpt
parted --script "$DISK" mkpart ESP fat32 1MiB 513MiB
parted --script "$DISK" set 1 boot on
parted --script "$DISK" mkpart primary 513MiB 100%

# Create filesystems
mkfs.vfat -F 32 "${DISK}1"

# Encrypt the second partition with LUKS
echo -n "$KEY" | cryptsetup luksFormat --batch-mode --align-payload=8192 -s 256 -c aes-xts-plain64 "${DISK}2"

# Open the encrypted partition
echo -n "$KEY" | cryptsetup open "${DISK}2" cryptsystem

# Format the encrypted partition with Btrfs
mkfs.btrfs -f /dev/mapper/cryptsystem

# Create Subvolumes
mount /dev/mapper/cryptsystem /mnt
btrfs subvolume create /mnt/@nixos
btrfs subvolume create /mnt/@nixos/@root
btrfs subvolume create /mnt/@nixos/@log
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@persist
btrfs subvolume create /mnt/@persist/@etc
btrfs subvolume create /mnt/@persist/@home

# Setup Mounts
umount /mnt
# 
echo "Disk partitioned, encrypted, and formatted successfully."
