#!/usr/bin/env bash
#----------------------------------------------------------------------------------
#  __________                 ._____      __                    .__              
#  \______   \ _________    __| _/  \    /  \____ ______________|__| ___________ 
#   |       _//  _ \__  \  / __ |\   \/\/   |__  \\_  __ \_  __ \  |/  _ \_  __ \
#   |    |   (  <_> ) __ \/ /_/ | \        / / __ \|  | \/|  | \/  (  <_> )  | \/
#   |____|_  /\____(____  |____ |  \__/\  / (____  /__|   |__|  |__|\____/|__|   
#          \/           \/     \/       \/       \/                              
#----------------------------------------------------------------------------------
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "-------------------------------------------------"
echo "Setting up mirrors for optimal download          "
echo "-------------------------------------------------"
iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -S --noconfirm pacman-contrib terminus-font
setfont ter-v22b
sed -i 's/^#Para/Para/' /etc/pacman.conf
pacman -S --noconfirm reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

echo -e "----------------------------------------------------------------------------------"
echo -e "  __________                 ._____      __                    .__                "
echo -e "  \\______   \\ _________    __| _/  \\    /  \\____ ______________|__| ___________   "
echo -e "   |       _//  _ \\__  \\  / __ |\\   \\/\\/   |__  \\\\_  __ \\_  __ \\  |/  _ \\_  __ \\  "
echo -e "   |    |   (  <_> ) __ \\/ /_/ | \\        / / __ \\|  | \\/|  | \\/  (  <_> )  | \\/  "
echo -e "   |____|_  /\\____(____  |____ |  \\__/\\  / (____  /__|   |__|  |__|\\____/|__|     "
echo -e "          \\/           \\/     \\/       \\/       \\/                                "
echo -e "----------------------------------------------------------------------------------"
echo -e "-Setting up $iso mirrors for faster downloads"
echo -e "----------------------------------------------------------------------------------"

reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
mkdir /mnt


echo -e "\nInstalling prereqs...\n$HR"
pacman -S --noconfirm gptfdisk btrfs-progs

echo "-------------------------------------------------"
echo "-------select your disk to format----------------"
echo "-------------------------------------------------"
disks=$(lsblk)
echo $disks
echo "Please enter disk to work on: (example /dev/sda)"
while :; do
    read -p "Disk: " disk
    [[ disks != *"$disk"* ]]
done
echo "THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK"
read -p "Are you sure you want to continue (y/N):" formatdisk

case $formatdisk in
    y|Y|yes|Yes|YES)
        echo "--------------------------------------"
        echo -e "\nFormatting disk...\n$HR"
        echo "--------------------------------------"

        # Disk Preparation, -a 2048 is a default parameter; nothing risky
        read -p "Zap Disk? (y/N):" zapMe
        case $zapMe in
            y|Y|yes|Yes|YES)
                echo "Zapping..."
                sgdisk -Z ${DISK} # Zeroes the disk
                ;;
        esac
        sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

        # create partitions
        sgdisk -n 1::+1M   --typecode=1:ef02 --change-name=1:'bios' ${DISK} # partition 1 (BIOS Boot Partition; handled by GRUB)
        sgdisk -n 2::+512M --typecode=2:ef00 --change-name=2:'efi'  ${DISK} # partition 2 (UEFI Boot Partition)
        sgdisk -n 3::-0    --typecode=3:8300 --change-name=3:'root' ${DISK} # partition 3 (Root), default start, remaining

        # Enable BIOS boot bit iff UEFI is not detected
        if [[ ! -d "/sys/firmware/efi" ]]; then
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

        echo -e "\nCreating Filesystems...\n$HR"
        # Make Filesystems
        # EFI: 512M vfat
        mkfs.vfat -F32 -n "efi" "${DISKP}2"

        # Boot partition: encapsulated luks btrfs
        # You will be asked for a password twice now
        echo "Launching Cryptsetup, you will be asked to enter your encryption password"
        cryptsetup luksFormat "${DISKP}3"
        
        echo "\nDumping encrypted partition information..."
        cryptsetup luksDump "${DISKP}3"
        read -p "Verify the luks header is correct and any key to continue..."

        # Formating internal partition to btrfs
        echo "Opening encrypted partition, you will be asked for your password"
        cryptsetup open "${DISKP}3" cryptroot

        echo "Configuring BTRFS partition"
        mkfs.btrfs -L root /dev/mapper/cryptroot
        mount /dev/mapper/cryptroot /mnt
        
        # Del existing sub-volumes (?)
        ls /mnt | xargs btrfs subvolume delete

        # https://wiki.archlinux.org/title/Btrfs#Partitionless_Btrfs_disk
        # @ /
        # @home /home
        # @cache /var/cache
        # @log /var/log
        # @swap /swap
        # @snapshots /.snapshots
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@cache
        btrfs subvolume create /mnt/@log
        btrfs subvolume create /mnt/@swap
        btrfs subvolume create /mnt/@snapshots
        
        umount /mnt
        ;;
    *)
        echo "Rebooting in 3 Seconds ..." && sleep 1
        echo "Rebooting in 2 Seconds ..." && sleep 1
        echo "Rebooting in 1 Second ..." && sleep 1
        reboot now
        ;;
esac

# Mount new filesystem
# Compression should be beneficial according to the wiki
mount -o compress=zstd,subvol=@ /dev/mapper/cryptroot /mnt

mkdir -p /mnt/home
mkdir -p /mnt/var/cache
mkdir -p /mnt/var/log
mkdir -p /mnt/swap
mkdir -p /mnt/.snapshots
mkdir -p /mnt/boot

mount -t vfat -L efi /mnt/boot
mount -o compress=zstd,subvol=@home      /dev/mapper/cryptroot /mnt/home
mount -o compress=zstd,subvol=@cache     /dev/mapper/cryptroot /mnt/var/cache
mount -o compress=zstd,subvol=@log       /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@swap                    /dev/mapper/cryptroot /mnt/swap
mount -o compress=zstd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots

if ! grep -qs '/mnt' /proc/mounts; then
    echo "Drive is not mounted, can not continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi

# Create btrfs swap file, substitute count for GB of ram if you want hibernate
# Use dd for allocation, not fallocate (due to holes, needs to be continuous)
read -p "Creating /swap/swapfile, enter size in GBs (RAM GBs + 1 for hibernate, ex: 17): " swapSize
cd /mnt/swap
touch ./swapfile
chmod 600 ./swapfile
chattr +C ./swapfile
btrfs property set ./swapfile compression none
dd if=/dev/zero of=./swapfile bs=1G count=${swapSize} status=progress
mkswap ./swapfile
swapon ./swapfile

# Generate fstab
genfstab -U /mnt > /mnt/etc/fstab
echo "\nDumping fstab, verify it's correct..."
cat /mnt/etc/fstab
read -p "Press any key to continue..."

echo "--------------------------------------"
echo "-- Arch Install on Main Drive       --"
echo "--------------------------------------"
pacstrap --noconfirm --needed /mnt base base-devel linux linux-firmware btrfs-progs archlinux-keyring
pacstrap --noconfirm --needed /mnt linux-tools linux-lts vim nano sudo wget linbnewt
genfstab -U /mnt >> /mnt/etc/fstab

# Add ubuntu keyserver, copy install script to new system, copy updated mirrorlist
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp -R ${SCRIPT_DIR} /mnt/root/install-script
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

echo "--------------------------------------"
echo "--GRUB BIOS Bootloader Install&Check--"
echo "--------------------------------------"
if [[ ! -d "/sys/firmware/efi" ]]; then
    grub-install --boot-directory=/mnt/boot ${DISK}
fi

echo "--------------------------------------"
echo "--   SYSTEM READY FOR 1-setup       --"
echo "--------------------------------------"
