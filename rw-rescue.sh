#!/bin/bash
echo -e "----------------------------------------------------------------------------------"
echo -e "  __________                 ._____      __                    .__                "
echo -e "  \\______   \\ _________    __| _/  \\    /  \\____ ______________|__| ___________   "
echo -e "   |       _//  _ \\__  \\  / __ |\\   \\/\\/   |__  \\\\_  __ \\_  __ \\  |/  _ \\_  __ \\  "
echo -e "   |    |   (  <_> ) __ \\/ /_/ | \\        / / __ \\|  | \\/|  | \\/  (  <_> )  | \\/  "
echo -e "   |____|_  /\\____(____  |____ |  \\__/\\  / (____  /__|   |__|  |__|\\____/|__|     "
echo -e "          \\/           \\/     \\/       \\/       \\/                                "
echo -e "----------------------------------------------------------------------------------"
echo -e "- Remounts encrypted Arch drive"
echo -e "----------------------------------------------------------------------------------"
sleep 1
set -e

echo "Please select the disk you installed Arch on:"
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
do
  DISK=$ENTRY
  if [[ -n "$DISK" ]]; then
    if [[ ${DISK} =~ "nvme" ]]; then
      DISKP=${DISK}p
    else
      DISKP=${DISK}
    fi
    echo "Remounting LUKS partition ${DISKP}3, with /boot ${DISKP}2"
    break
  fi
done

read -r -s -p "Enter encryption password: " password
echo ""
echo -n "$password" | cryptsetup open "${DISKP}3" cryptroot -d -
mountpoint -q "/mnt" && umount -R "/mnt"

# Format warning
read -p "Run disk check? - fsck (y/N):" formatdisk
case $formatdisk in
  y|Y|yes|Yes|YES)
    btrfs check /dev/mapper/cryptroot
    ;;
  *)
    ;;
esac

echo ""
echo "--------------------------------------------------------------------------"
echo "- Remounting disc  "
echo "--------------------------------------------------------------------------"

mountpoint -q "/mnt" && umount -R "/mnt"
mkdir -p /mnt

mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@          /dev/mapper/cryptroot /mnt
mount -t vfat                                                            "${DISKP}2"           /mnt/boot
mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@home      /dev/mapper/cryptroot /mnt/home
mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@cache     /dev/mapper/cryptroot /mnt/var/cache
mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@log       /dev/mapper/cryptroot /mnt/var/log
mount -o defaults,noatime,subvol=@swap                                   /dev/mapper/cryptroot /mnt/swap
mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@homesnaps /dev/mapper/cryptroot /mnt/home/.snapshots

echo "--------------------------------------------------------------------------"
echo "- Disc remounted  "
echo "--------------------------------------------------------------------------"