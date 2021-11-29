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

echo "Please select the disk you installed Arch on with the previous script:"
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
do
  DISK=$ENTRY
  if [[ -n "$DISK" ]]; then
    echo "Installing GRUB on $DISK."
    if [[ ${DISK} =~ "nvme" ]]; then
      CRYPT_PART=${DISK}p3
    else
      CRYPT_PART=${DISK}3
    fi
    echo "Kernel will unlock partition ${CRYPT_PART}."
    break
  fi
done

iso=$(curl -4 ifconfig.co/country-iso)
echo ""
echo "--------------------------------------------------------------------------"
echo "- Setting $iso up mirrors for optimal download         "
echo "--------------------------------------------------------------------------"
# Parallel downloads
sed -i 's/^#Para/Para/' /etc/pacman.conf
pacman -S --noconfirm rsync reflector 
# Sort mirrorlist based on country
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
pacman -S --noconfirm pacman-contrib curl

echo "--------------------------------------------------------------------------"
echo "- Changing make config based on cores         "
echo "--------------------------------------------------------------------------"
nc=$(grep -c ^processor /proc/cpuinfo)
echo "You have " $nc" cores."
echo "Changing the makeflags for "$nc" cores."
cp /etc/makepkg.conf /etc/makepkg.conf.bak
TOTALMEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /etc/makepkg.conf
if [[  $TOTALMEM -gt 8000000 ]]; then
  echo "Changing the compression settings for "$nc" cores."
  sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /etc/makepkg.conf
fi

echo "--------------------------------------------------------------------------"
echo "- Setup Language, locale, and timezone       "
echo "--------------------------------------------------------------------------"
source ${SCRIPT_DIR}/install.conf || /bin/true
for loc in "${locale_gen[@]:-("en_US.UTF-8\ UTF-8")}"; do
  echo "Installing Locale $loc"
  sed -i "s/#${loc}/${loc}/" /etc/locale.gen
done
locale-gen
localectl --no-ask-password set-locale LANG="${locale_lang:-en_US.UTF-8}" LC_TIME="${locale_lang:-en_US.UTF-8}"
localectl --no-ask-password set-keymap ${keymap:-us}

ln -sf /usr/share/zoneinfo/${timezone:-America/Chicago} /etc/localtime
hwclock --systohc

# Set keymaps

# Add sudo no password rights
echo "Sudoers: wheel group will require no password to run sudo, edit /etc/sudoers"
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

# Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

echo "--------------------------------------------------------------------------"
echo "--  Configuring mkinitcpio"
echo "--------------------------------------------------------------------------"
# Configuring /etc/mkinitcpio.conf.
echo "Configuring /etc/mkinitcpio.conf."
# mkinitpio hooks with sd-encrypt:
# systemd supports LUKS2 unlock by password, with timeouts and preview, and by TPM
# https://wiki.archlinux.org/title/mkinitcpio#HOOKS
sed -i "s,^HOOKS,HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems)\n#HOOKS,g" /etc/mkinitcpio.conf
# Change initramfs compression from gzip (default) to zstd
sed -i "s,^#COMPRESSION=[\(\"]zstd[\)\"],COMPRESSION=\"zstd\",g" /etc/mkinitcpio.conf
# Create vconsole fle
echo "KEYMAP=${keymap:-us}" > /etc/vconsole.conf

# Ignore:
# ==> WARNING: Possibly missing firmware for module: aic94xx
# ==> WARNING: Possibly missing firmware for module: wd719x
# ==> WARNING: Possibly missing firmware for module: xhci_pci
# https://wiki.archlinux.org/title/Mkinitcpio#Possibly_missing_firmware_for_module_XXXX
# They only appear for fallback generation, which enables all modules
mkinitcpio -P

# Generate initramfs with keyfile to use with GRUB, so password is not entered twice
# https://wiki.gentoo.org/wiki/Custom_Initramfs#Creating_a_separate_file
echo -e "/crypt\n/crypt/keyfile.bin" | cpio --create --verbose --format=newc | gzip --best > /boot/initramfs-keyfile.cpio.gz

echo "--------------------------------------------------------------------------"
echo "- Generating Kernel Command Line "
echo "--------------------------------------------------------------------------"
# Setting up LUKS2 encryption in grub.
LUKS_UUID=$(blkid -s UUID -o value ${CRYPT_PART})
echo "LUKS partition (${CRYPT_PART}) UUID: ${LUKS_UUID}"

# BTRFS hibernate, it has to be in btrfs because we want to use an encrypted swap
# That's also variable in case you upgrade your ram or want to remove it in the future.
# https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation_into_swap_file_on_Btrfs
SWAP_UUID=$(findmnt -no UUID -T /swap/swapfile)
gcc -O2 -o ${SCRIPT_DIR}/btrfs_map_physical ${SCRIPT_DIR}/physical.c
SWAP_FILE_OFFSET=$(${SCRIPT_DIR}/btrfs_map_physical /swap/swapfile | egrep -om 1 "[[:digit:]]+$")
PAGE_SIZE=$(getconf PAGESIZE)
SWAP_OFFSET=$(expr $SWAP_FILE_OFFSET / $PAGE_SIZE)
echo "Swap file (UUID=${SWAP_UUID}) offset is $SWAP_FILE_OFFSET / $PAGE_SIZE = $SWAP_OFFSET"
# Why hibernate? Because if you leave your laptop on standby it will run until
# it runs out of battery and you'll lose your session.
# With hibernate the laptop will automatically turn off after a set amount of hours.
# Bonus: the luks partition will be locked, preventing cold boot attacks (if TPM is disabled).

# Timeout doesn't work, systemd enters emergency shell and user can retry
# So, timeouts and limited retries are disabled for now
CMD_LINE="quiet rd.luks.name=$LUKS_UUID=cryptroot root=/dev/mapper/cryptroot apparmor=1 security=apparmor udev.log_priority=3 resume=UUID=${SWAP_UUID} resume_offset=${SWAP_OFFSET}"
echo "Kernel CMD: ${CMD_LINE}"

echo "--------------------------------------------------------------------------"
echo "- GRUB Bootloader Install&Check"
echo "--------------------------------------------------------------------------"
# GRUB will be installed as a failsafe in case something goes wrong.
# It will be signed to be bootable with secure boot.
# It will also be unlocked so that you can enter any settings to make sure you
# can boot. 

# /boot is encrypted so TPM support with GRUB is not possible. Besides, by booting
# directly with an EFISTUB you can lower boot time by 5s.
# GRUB will mess up PCRs 8 and 9, so you can make sure it can't be used with an 
# alternate config and kernel to bypass the TPM by binding PCR 8

sed -i "s,^GRUB_CMDLINE_LINUX_DEFAULT,GRUB_CMDLINE_LINUX_DEFAULT=\"${CMD_LINE} rd.luks.options=$LUKS_UUID=discard rd.luks.key=$LUKS_UUID=/crypt/keyfile.bin\"\n#GRUB_CMDLINE_LINUX_DEFAULT,g" /etc/default/grub
# Add tpm and crypto modules
GRUB_MODULES="keylayouts part_gpt part_msdos normal gzio fat btrfs cryptodisk luks2 pbkdf2 gcry_rijndael gcry_sha256 gcry_sha512"
sed -i "s,^GRUB_PRELOAD_MODULES,GRUB_PRELOAD_MODULES=\"$GRUB_MODULES\"\n#GRUB_PRELOAD_MODULES,g" /etc/default/grub

# Since GRUB support is integrated as a failsafe, using a hidden menu is pointless.
# # Hide grub menu, remember last kernel
# echo "GRUB menu will be hidden, hold shift to access during boot"
# sed -i "s,^GRUB_TIMEOUT_STYLE=menu,GRUB_TIMEOUT_STYLE=hidden,g"  /etc/default/grub
# sed -i "s,^GRUB_TIMEOUT=5,GRUB_TIMEOUT=3,g"                      /etc/default/grub
# sed -i "s,^GRUB_DEFAULT=0,GRUB_DEFAULT=saved,g"                  /etc/default/grub
# sed -i "s,^#GRUB_SAVEDEFAULT,GRUB_SAVEDEFAULT,g"                 /etc/default/grub

# Enable cryptodisk support in the grub image (not working for now for LUKS2)
sed -i "s,^#GRUB_ENABLE_CRYPTODISK=y,GRUB_ENABLE_CRYPTODISK=y,g" /etc/default/grub
# Add unlock keyfile to ramdisk
echo "GRUB_EARLY_INITRD_LINUX_CUSTOM=\"initramfs-keyfile.cpio.gz\"" >> /etc/default/grub

# Has to be in chroot to run correctly, besides grub isn't available in the iso.
# Also, luks2 support is preliminary so we have to install grub manually
# the `cryptomount` command doesn't support `-` for LUKS2 so grub-install doesn't work
CONFIG=$(mktemp /tmp/grub-config.XXXXX) 
cat >"$CONFIG" <<EOF
cryptomount -u ${LUKS_UUID//-/}

set root=crypto0
set prefix=(crypto0)/@/boot/grub

insmod normal
normal
EOF

# Manual install inspired by:
# https://github.com/coreos/scripts/blob/master/build_library/grub_install.sh

# Use grub-install to prime locale, font, pc modules
grub-install --target=i386-pc ${DISK} --no-bootsector
# Copy efi dependencies manually
cp -Rf /usr/lib/grub/x86_64-efi /boot/grub/x86_64-efi

GRUB_IMG=$(mktemp /tmp/grub-img.XXXXX) 

# EFI Install
# Install on both default location and `distroname` dir
# default location will be unsigned
mkdir -p /efi/EFI/BOOT
mkdir -p /efi/EFI/${distroname:-RoadwarriorArch}
grub-mkimage -p '/boot/grub' -O x86_64-efi \
    -c "$CONFIG" -o $GRUB_IMG $GRUB_MODULES
cp $GRUB_IMG /efi/EFI/BOOT/BOOTX64.EFI
cp $GRUB_IMG /efi/EFI/${distroname:-RoadwarriorArch}/grubx64.efi

# BIOS Install
grub-mkimage -p '/boot/grub' -O i386-pc \
  -c "$CONFIG" -o "/boot/grub/core-bios.img" $GRUB_MODULES biosdisk serial
grub-bios-setup -d '/boot/grub' -b 'i386-pc/boot.img' -c 'core-bios.img' \
  --device-map=/dev/null $DISK

rm "$CONFIG" "$GRUB_IMG"

# Automatic Install
# # if [[ ! -d "/sys/firmware/efi" ]]; then
#   grub-install --target=i386-pc ${DISK} --modules="$GRUB_MODULES"
# # fi
# grub-install --target=x86_64-efi --efi-directory=/efi/ --no-nvram \
#   --bootloader-id=${distroname:-RoadwarriorArch} --modules="$GRUB_MODULES"
grub-mkconfig -o /boot/grub/grub.cfg

echo "--------------------------------------------------------------------------"
echo "- Secure boot Key creation and Setup"
echo "--------------------------------------------------------------------------"

# We are going to setup a key directory for secure boot
# We are not going to enroll the keys automatically to not mess with the BIOS
# https://www.rodsbooks.com/efi-bootloaders/controlling-sb.html#creatingkeys
# https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Creating_keys

# Certain laptops may be bricked by using KeyTool or disabling the microsoft keys
# - Certain Thinkpad models can have their BIOS corrupted by keytool (T14 gen 1 etc)
# - Certain laptops with an NVIDIA GPU that's directly connected to the onboard display
#   (after disabling optimus) require loading an option ROM that's signed using microsoft keys
#   to display the BIOS. Without it, you'll either need to plug your laptop to a VGA display
#   or reset it blindly, because the onboard display will be disabled before loading the OS.

# However, no laptops are bricked by using the onboard BIOS utility and if you
# don't touch the rest of the keys the NVIDIA option ROM will load normally.
# If your BIOS doesn't allow for enrolling keys manually, you might have to use KeyTool and reset the keys.
# In that case, check for a reset to factory option for the built-in keys. 
# Otherwise, i'd be a good idea to also save your original keys by following the arch guide.

# In my case, Lenovo allows me to browse the keystore from the bios and add my
# DB key by browsing the connected storage devices. 
# I can leave the original PK, KEK, db, and dbx as they are.
# The value of the TPM2 PCR 7 is also influenced by the loaded keys during boot
# So, an attacker can't unlock my TPM-protected LUKS2 volume by running code
# not signed by me. 
# This is not universally the case, for your system PCR 7 might only be influenced
# only by whether secure boot is on. That would make relying only on PCR 7 insecure...

# According to Microsoft:
# Before launching an EFI Driver or an EFI Boot Application (and regardless of 
# whether the launch is due to the EFI Boot Manager picking an image from the 
# DriverOrder or BootOrder UEFI variables or an already launched image calling 
# the UEFI LoadImage() function), the UEFI firmware SHALL measure the entry in 
# the EFI_IMAGE_SECURITY_DATABASE_GUID/EFI_IMAGE_SECURITY_DATABASE variable that 
# was used to validate the EFI image into PCR[7]. 
# https://docs.microsoft.com/en-us/windows-hardware/test/hlk/testref/trusted-execution-environment-efi-protocol#appendix-a-static-root-of-trust-measurements

# That means that any modification to the KeyStore would prevent unlocking the volume
# Using an EFI image signed with a proper key which is not the same would also not unlock the volume.

echo "Creating Secureboot keys at /crypt/sb"
echo "GRUB and EFI Stubs will be signed by /crypt/sb/DB.key"
echo "Enroll it in the BIOS manually by copying /crypt/sb/DB.crt to a flash drive"
echo "PK, KEK keys have also been created"
echo "You don't need to enroll them if your bios allows manual editing of the keystore"
mkdir -p /crypt/sb
cd /crypt/sb

################################################################################
# Sourced from:
# https://www.rodsbooks.com/efi-bootloaders/controlling-sb.html#creatingkeys
# Python dependencry for UUID removed.

#!/bin/bash
# Copyright (c) 2015 by Roderick W. Smith
# Licensed under the terms of the GPL v3
# echo -n "Enter a Common Name to embed in the keys: "
# read NAME
NAME=${distroname:-RoadwarriorArch}

openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME PK/" -keyout PK.key \
        -out PK.crt -days 3650 -nodes -sha256
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME KEK/" -keyout KEK.key \
        -out KEK.crt -days 3650 -nodes -sha256
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=$NAME DB/" -keyout DB.key \
        -out DB.crt -days 3650 -nodes -sha256
openssl x509 -in PK.crt -out PK.cer -outform DER
openssl x509 -in KEK.crt -out KEK.cer -outform DER
openssl x509 -in DB.crt -out DB.cer -outform DER


GUID=$(uuidgen --random)
echo $GUID > GUID.txt

cert-to-efi-sig-list -g $GUID PK.crt PK.esl
cert-to-efi-sig-list -g $GUID KEK.crt KEK.esl
cert-to-efi-sig-list -g $GUID DB.crt DB.esl
rm -f noPK.esl
touch noPK.esl

sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt PK PK.esl PK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt PK noPK.esl noPK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k PK.key -c PK.crt KEK KEK.esl KEK.auth
sign-efi-sig-list -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
                  -k KEK.key -c KEK.crt db DB.esl DB.auth

chmod 0600 *.key

echo ""
echo ""
echo "For use with KeyTool, copy the *.auth and *.esl files to a FAT USB"
echo "flash drive or to your EFI System Partition (ESP)."
echo "For use with most UEFIs' built-in key managers, copy the *.cer files;"
echo "but some UEFIs require the *.auth files."
echo ""
################################################################################

echo "Keys created"
chmod 700 -R /crypt

echo "Configuring sbupdate (installed later)"
cp ~/install-script/sbupdate.conf /etc/sbupdate.conf
sed -i "s,_cmdline_,${CMD_LINE} rd.luks.options=$LUKS_UUID=discard\,timeout=0\,tries=0\,tpm2-device=auto,g" /etc/sbupdate.conf
sed -i "s,_distroname_,${distroname:-RoadwarriorArch},g" /etc/sbupdate.conf

echo "--------------------------------------------------------------------------"
echo "- Creating user"
echo "--------------------------------------------------------------------------"
if ! source ${SCRIPT_DIR}/install.conf; then
  read -p "Enter username: " username
  read -p "Enter password: " password
  read -p "Enter hostname: " hostname
  echo "username=$username\npassword=$password\nhostname=$hostname" >> ${SCRIPT_DIR}/install.conf
fi

if [ $(whoami) = "root" ] && [ -z $(users | grep "$username") ]; then
  useradd -m -G wheel -s /bin/bash $username || /bin/true
  echo "$username:$password" | chpasswd
  echo $hostname > /etc/hostname
fi

echo "--------------------------------------------------------------------------"
echo "- Installing base system packages       "
echo "--------------------------------------------------------------------------"
pi () {
  pacman -S --noconfirm --needed $@ || exit 1
}

# Graphics Drivers find and install
if lspci | grep -E "NVIDIA|GeForce"; then
  # FIXME: add optimus setup, test
  pi nvidia
  nvidia-xconfig
elif lspci | grep -E "Radeon"; then
  # FIXME: test
  pi xf86-video-amdgpu
elif lspci | grep -E "VGA compatible controller: Intel"; then
  # The followind packages are required for chromium hw acceleration
  # Intel drivers are provided by the mesa package and kernel
  # Don't install xf86-video-intel! (at least for new laptops)
  # https://wiki.archlinux.org/title/intel_graphics#Installation
  # https://wiki.archlinux.org/title/Hardware_video_acceleration
  pi intel-media-driver libva-utils intel-gpu-tools vulkan-icd-loader vulkan-intel

  # TODO: older intel gpus
fi

echo "#### Install mesa and xorg to power display"
pi mesa xorg xorg-server xorg-apps xorg-drivers xorg-xkill xorg-xinit
echo "#### Install plasma group + kde, desktop environment, sddm login"
pi plasma kde-utilities kde-system sddm zeroconf-ioslave system-config-printer
echo "#### Install a subsection of kde-applications, which is too large"
pi gwenview okular spectacle
echo "#### Install networking"
pi networkmanager net-tools inetutils

echo "#### Install Compression Utils"
pi ark zip unzip unrar p7zip lzop 
echo "#### Install Terminal Utils (use zsh!)"
pi zsh bash-completion
# Available with oh-my-zsh, install from there
# 'zsh-syntax-highlighting' 
# 'zsh-autosuggestions'

echo "#### Install audio packages and manager"
pi alsa-plugins alsa-tools alsa-utils alsa-ucm-conf sof-firmware
pi pulseaudio pulseaudio-alsa pulseaudio-bluetooth
echo "#### Install Bluetooth provider"
pi bluez bluez-libs bluez-utils                    

echo "#### Install Fuse mounts, mount GDrive, OneDrive etc with rclone"
pi rclone sshfs fuse2 fuse3
echo "#### Install Python"
pi python python2 python-pip python2-pip

echo "#### Install a collection of useful tools"
pi git openssh htop bmon nano os-prober openbsd-netcat ufw lsof vim wget rsync pacman-contrib openvpn
echo "#### Install Disk Utils"
pi gparted gptfdisk ntfs-3g util-linux dosfstools exfat-utils gnome-disk-utility

echo "#### Install Laptop energy management (TLP) and TPM support"
pi tlp tlp-rdw tpm2-tools

echo "#### Install Snapper "
pi snapper grub-btrfs # snap-pac <- enable only after installing software

# Gaming specific
# pi lutris steam gamemode
# Wine, avoid if possible
# pi wine wine-gecko wine-mono winetrics
# Virtual machines, alternative to Virtualbox
# pi qemu virt-manager virt-viewer 

echo "#### Install Fun packages"
pi neofetch cmatrix archlinux-wallpaper 

echo "#### Install Misc Packages"
PKGS=(
  'cronie'          # Crontab
  'cups'            # Printer management
  # 'picom'         # Compositor that helps with tearing (?)
  'powerline-fonts' # powerline fonts for vim/ZSH
  # 'synergy'       # Share mouse between multiple PCs
  'traceroute'      # allows viewing network hops to a host
  'usbutils'        # lists usb devices
  'xdg-user-dirs'   # localizes user dirs such as ~/Music
)

for PKG in "${PKGS[@]}"; do
  echo "INSTALLING: ${PKG}"
  sudo pacman -S "$PKG" --noconfirm --needed
done

echo -e "\nDone!\n"

echo "--------------------------------------------------------------------------"
echo "- Enable Essential Services "
echo "--------------------------------------------------------------------------"
systemctl enable sddm
systemctl enable cups
systemctl enable cronie
systemctl enable systemd-timesyncd
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable apparmor
systemctl enable tlp
systemctl enable grub-btrfs.path # adds snapshots to grub

echo "--------------------------------------------------------------------------"
echo "- Configure snapper "
echo "--------------------------------------------------------------------------"

# https://wiki.archlinux.org/title/snapper

# Emulate the following command
# snapper -c root create-config /
# It does 3 things:
# - create a volume for .snapshots (in @; we want outside which is why we do this)
# - create the following config file
# - add an entry to /etc/conf.d/snapper
# Why: if we create @snapshots and map it to /.snapshots, the command doesn't work

# Bi-daily snapshots for system
cp ${SCRIPT_DIR}/snapper_sample.conf /etc/snapper/configs/root
cat >> /etc/snapper/configs/root <<-EOL
SUBVOLUME="/"
TIMELINE_MIN_AGE="21600"
TIMELINE_LIMIT_HOURLY="2"
TIMELINE_LIMIT_DAILY="5"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="2"
TIMELINE_LIMIT_YEARLY="0"
EOL

# Bihourly snapshots for home dir
# Tempting to create weekly/yearly snapshots, but that means you can't delete
# files to save space anymore...
cp ${SCRIPT_DIR}/snapper_sample.conf /etc/snapper/configs/home
cat >> /etc/snapper/configs/home <<-EOL
SUBVOLUME="/home"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
EOL

# Add entries to central config
sed -i 's/^SNAPPER/SNAPPER_CONFIGS=\"root home\"\n#SNAPPER/' /etc/conf.d/snapper

# Allow access by sudoers to snapshots
chmod a+rx /.snapshots
chown :wheel /.snapshots
chmod a+rx /home/.snapshots
chown :wheel /home/.snapshots

echo "--------------------------------------------------------------------------"
echo "- Finished system installation"
echo "--------------------------------------------------------------------------"