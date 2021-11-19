#!/usr/bin/env bash
#----------------------------------------------------------------------------------
#  __________                 ._____      __                    .__              
#  \______   \ _________    __| _/  \    /  \____ ______________|__| ___________ 
#   |       _//  _ \__  \  / __ |\   \/\/   |__  \\_  __ \_  __ \  |/  _ \_  __ \
#   |    |   (  <_> ) __ \/ /_/ | \        / / __ \|  | \/|  | \/  (  <_> )  | \/
#   |____|_  /\____(____  |____ |  \__/\  / (____  /__|   |__|  |__|\____/|__|   
#          \/           \/     \/       \/       \/                              
#----------------------------------------------------------------------------------
# if running the script multiple times, cleanup...
# Remove swap, btrfs mounts, and close luks container
[[ -n $(cat /proc/swaps | grep swap) ]] && swapoff /mnt/swap/swapfile
mountpoint -q "/mnt" && umount -R "/mnt"
if [ -b /dev/mapper/cryptroot ]; then
    cryptsetup close cryptroot
fi
# partprobe 2>/dev/null
rm -r -f /mnt

# Exit on error
set -e

echo -e "----------------------------------------------------------------------------------"
echo -e "  __________                 ._____      __                    .__                "
echo -e "  \\______   \\ _________    __| _/  \\    /  \\____ ______________|__| ___________   "
echo -e "   |       _//  _ \\__  \\  / __ |\\   \\/\\/   |__  \\\\_  __ \\_  __ \\  |/  _ \\_  __ \\  "
echo -e "   |    |   (  <_> ) __ \\/ /_/ | \\        / / __ \\|  | \\/|  | \\/  (  <_> )  | \\/  "
echo -e "   |____|_  /\\____(____  |____ |  \\__/\\  / (____  /__|   |__|  |__|\\____/|__|     "
echo -e "          \\/           \\/     \\/       \\/       \\/                                "
echo -e "----------------------------------------------------------------------------------"
sleep 2

iso=$(curl -4 ifconfig.co/country-iso)
echo ""
echo "--------------------------------------------------------------------------"
echo "- Setting $iso up mirrors for optimal download         "
echo "--------------------------------------------------------------------------"
# Parallel downloads
sed -i 's/^#Para/Para/' /etc/pacman.conf
# Sort mirrorlist based on country
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

timedatectl set-ntp true
mkdir -p /mnt

echo "--------------------------------------------------------------------------"
echo "- Disk Partitioning  "
echo "--------------------------------------------------------------------------"
echo "Please select the disk to work on:"
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
do
  DISK=$ENTRY
  if [[ -n "$DISK" ]]; then
    echo "Installing Arch Linux on $DISK."
    break
  fi
done

# Format warning
echo "THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK"
read -p "Are you sure you want to continue (y/N):" formatdisk
case $formatdisk in
  y|Y|yes|Yes|YES)
    ;;
  *)
    echo "Exiting..."
    exit 1
    ;;
esac

echo "--------------------------------------------------------------------------"
echo "- Formatting disk..."
echo "--------------------------------------------------------------------------"

# Disk Preparation, -a 2048 is a default parameter; nothing risky
sgdisk -Z ${DISK} # Zeroes the disk
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1::+1M   --typecode=1:ef02 --change-name=1:'BIOS' ${DISK} # partition 1 (BIOS Boot Partition; handled by GRUB)
sgdisk -n 2::+512M --typecode=2:ef00 --change-name=2:'EFI'  ${DISK} # partition 2 (UEFI Boot Partition)
sgdisk -n 3::-0    --typecode=3:8300 --change-name=3:'LUKS' ${DISK} # partition 3 (LUKS container), default start, remaining

# Enable BIOS boot bit iff UEFI is not detected
if [[ ! -d "/sys/firmware/efi" ]]; then
  echo "UEFI mode not detected. BIOS support will be enabled. You should use UEFI."
  read -p "ctrl-c to exit so you can check the BIOS, or press any key to continue..."
  sgdisk -A 1:set:2 ${DISK}
fi

# NVMe partitions are in the style /dev/nvme0n1p2
# SATA partitions are in the style /dev/sda1
# Add p to disk name if nvme
if [[ ${DISK} =~ "nvme" ]]; then
  DISKP=${DISK}p
else
  DISKP=${DISK}
fi

echo "--------------------------------------------------------------------------"
echo "- Creating File Systems"
echo "--------------------------------------------------------------------------"
# Make Filesystems
echo "Creating a EFI 512M vfat partition"
mkfs.vfat -F32 -n "EFI" "${DISKP}2"

# Boot partition: encapsulated luks btrfs
# You will be asked for a password twice now
echo "Launching Cryptsetup, you will be asked to enter your encryption password"
while
  read -r -s -p "Password: " password
  echo ""
  read -r -s -p "  Verify: " verifyPassword
  echo ""
  [[ -z "$password" || "$password" != "$verifyPassword" ]]
do true; done
# cryptsetup has sane defaults (luks2, etc)
# https://wiki.archlinux.org/title/dm-crypt/Device_encryption#Encryption_options_for_LUKS_mode
echo -n "$password" | cryptsetup luksFormat "${DISKP}3" -d -

# Formating internal partition to btrfs
echo -e "\nOpening partition..."
echo -n "$password" | cryptsetup open "${DISKP}3" cryptroot -d -

echo "--------------------------------------------------------------------------"
echo "- Configuring BTRFS partition"
echo "--------------------------------------------------------------------------"
mkfs.btrfs -L ROOT /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt

# Del existing sub-volumes
[[ -n $(ls /mnt) ]] && ls /mnt | xargs btrfs subvolume delete

# https://wiki.archlinux.org/title/Btrfs#Partitionless_Btrfs_disk
# @          /
# @home      /home
# @cache     /var/cache
# @log       /var/log
# @swap      /swap
# @snapshots /.snapshots (created by snapper)
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@swap

umount /mnt

# Mount new filesystem
# Compression should be beneficial according to the wiki
# noatime disables read timestamps
# space_cache=v2 has recently become the default
# https://btrfs.wiki.kernel.org/index.php/Manpage/btrfs(5)
mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@ /dev/mapper/cryptroot /mnt

mkdir -p /mnt/home
mkdir -p /mnt/var/cache
mkdir -p /mnt/var/log
mkdir -p /mnt/swap
mkdir -p /mnt/boot

# Why mount EFI partition on boot instead of /boot/efi:
# In /boot/efi the kernel is encrypted, which limits evil maid attacks, doesn't leak
# information about your setup.
# However, GRUB has to perform the first unlock:
# GRUB doesn't support LUKS2 (completely), has no timeout option (if your Thnkpad turns
# on on its own in its bag it will turn into a Heatpad and drain its battery), and
# takes 20 seconds to unlock. Also, no retries. You make a mistake and you'll
# drop into a grub rescue shell. Then you either have to reboot the laptop or 
# remember a series of commands.
# https://wiki.archlinux.org/title/GRUB#Encrypted_/boot
mount -t vfat "${DISKP}2" /mnt/boot
mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@home      /dev/mapper/cryptroot /mnt/home
mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@cache     /dev/mapper/cryptroot /mnt/var/cache
mount -o defaults,compress=zstd,noatime,space_cache=v2,subvol=@log       /dev/mapper/cryptroot /mnt/var/log
mount -o defaults,noatime,subvol=@swap                                   /dev/mapper/cryptroot /mnt/swap

if ! grep -qs '/mnt' /proc/mounts; then
  echo "Drive is not mounted, can not continue"
  exit 1
fi

openssl genrsa -out /mnt/crypto_keyfile.bin 4096
chmod 600 /mnt/crypto_keyfile.bin
echo -n "$password" | cryptsetup luksAddKey "${DISKP}3" /mnt/crypto_keyfile.bin -d -
echo "Created /crypto_keyfile.bin as an alternative unlock key."
echo "Save it after install in case you forget your keyword."
read -p "Press any key to continue..."

# We expect to see only the 0 key slot occupied by a key
echo -e "\nDumping encrypted partition information..."
cryptsetup luksDump "${DISKP}3"
echo "Expected: 0 keyslot passphrase and 1 keyslot file"
read -p "Verify the luks header is correct and any key to continue..."

# Create btrfs swap file, substitute count for GB of ram if you want hibernate
# Use dd for allocation, not fallocate (due to holes, needs to be continuous)
TOTALMEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
swapSize=$(expr $TOTALMEM / 1000000 + 1) # N + 1 GB of memory, for hibernation
cd /mnt/swap
touch ./swapfile
chmod 600 ./swapfile
chattr +C ./swapfile
btrfs property set ./swapfile compression none
dd if=/dev/zero of=./swapfile bs=1G count=${swapSize} status=progress
mkswap ./swapfile
swapon ./swapfile

echo "--------------------------------------------------------------------------"
echo "-- Arch Install on Main Drive"
echo "--------------------------------------------------------------------------"
# Determine processor type and install microcode
proc_type=$(lscpu | awk '/Vendor ID:/ {print $3}')
case "$proc_type" in
  GenuineIntel)
    echo "Installing Intel microcode"
    MICROCODE=intel-ucode
    ;;
  AuthenticAMD)
    echo "Installing AMD microcode"
    MICROCODE=amd-ucode
    ;;
esac	

pacstrap /mnt --noconfirm --needed base base-devel linux linux-headers linux-firmware btrfs-progs archlinux-keyring grub efibootmgr $MICROCODE
# Optional tools, incl. lts kernel
pacstrap /mnt --noconfirm --needed linux-tools linux-lts linux-lts-headers apparmor vim nano zstd # sudo wget linbnewt

genfstab -U /mnt > /mnt/etc/fstab
echo -e "\nDumping fstab"
cat /mnt/etc/fstab
read -p "Verify fstab is correct and press any key to continue..."

# Add ubuntu keyserver
# https://wiki.archlinux.org/title/Pacman/Package_signing#Change_keyserver
echo "Adding ubuntu keyserver to pacman..."
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf

echo "--------------------------------------------------------------------------"
echo "--   SYSTEM READY FOR 1-setup"
echo "--------------------------------------------------------------------------"