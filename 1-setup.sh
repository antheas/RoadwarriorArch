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
echo -e "\n#Installed by Roadwarrior\n${locale_gen:-en_US.UTF-8 UTF-8}" >> /etc/locale.gen
locale-gen
localectl --no-ask-password set-locale LANG="${locale_lang:-en_US.UTF-8}" LC_TIME="${locale_lang:-en_US.UTF-8}"
localectl --no-ask-password set-keymap ${keymap:-us}

timedatectl --no-ask-password set-timezone ${timezone:-America/Chicago}
timedatectl --no-ask-password set-ntp 1

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
mkinitcpio -P

echo "--------------------------------------------------------------------------"
echo "- GRUB BIOS Bootloader Install&Check"
echo "--------------------------------------------------------------------------"
# Setting up LUKS2 encryption in grub.
echo "Setting up grub config."
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
# Bonus: the luks partition will be locked, preventing cold boot attacks.

sed -i "s,^GRUB_CMDLINE_LINUX_DEFAULT,GRUB_CMDLINE_LINUX_DEFAULT=\"quiet rd.luks.name=$LUKS_UUID=cryptroot rd.luks.options=$LUKS_UUID=tpm2-device=auto\,discard\,timeout=180 root=/dev/mapper/cryptroot apparmor=1 security=apparmor udev.log_priority=3 resume=UUID=${SWAP_UUID} resume_offset=${SWAP_OFFSET}\"\n#GRUB_CMDLINE_LINUX_DEFAULT,g" /etc/default/grub

# Has to be in chroot to run correctly, besides grub isn't available in the iso.
if [[ -d "/sys/firmware/efi" ]]; then
  grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=RoadwarriorArch
else
  grub-install --target=i386-pc --bootloader-id=RoadwarriorArch ${DISK}
fi
grub-mkconfig -o /boot/grub/grub.cfg

echo "--------------------------------------------------------------------------"
echo "- Creating user"
echo "--------------------------------------------------------------------------"
if ! source ${SCRIPT_DIR}/install.conf; then
  read -p "Enter username: " username
  read -p "Enter password: " password
  read -p "Enter hostname: " hostname
  echo "username=$username\npassword=$password\nhostname=$hostname" >> ${SCRIPT_DIR}/install.conf
fi

if [ $(whoami) = "root"  ]; then
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
  # FIXME: add optimus setup
  pi nvidia
  nvidia-xconfig
elif lspci | grep -E "Radeon"; then
 pi xf86-video-amdgpu
elif lspci | grep -E "Integrated Graphics Controller"; then
  pi intel-media-driver libva-utils intel-gpu-tools
# elif lspci | grep -E "Integrated Graphics Controller"; then
#   pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils --needed --noconfirm
fi

echo "#### Install mesa and xorg to power display"
pi mesa xorg xorg-server xorg-apps xorg-drivers xorg-xkill xorg-xinit
echo "#### Install plasma group + kde, desktop environment, sddm login"
pi plasma kde-utilities kde-system zeroconf-ioslave sddm
echo "#### Install a subsection of kde-applications, which is too large"
pi gwenview okular spectacle
echo "#### Install networking"
pi networkmanager

echo "#### Install Compression Utils"
pi ark zip unzip unrar p7zip lzop 
echo "#### Install Terminal Utils (use zsh!)"
pi zsh bash-completion
# Available with oh-my-zsh, install from there
# 'zsh-syntax-highlighting' 
# 'zsh-autosuggestions'

echo "#### Install audio packages and manager"
pi alsa-plugins alsa-tools alsa-utils                         
pi pulseaudio pulseaudio-alsa pulseaudio-bluetooth
echo "#### Install Bluetooth provider"
pi bluez bluez-libs bluez-utils                    

echo "#### Install Fuse mounts, mount GDrive, OneDrive etc with rclone"
pi rclone fuse2 fuse3
echo "#### Install Python"
pi python python2 python-pip python2-pip

echo "#### Install a collection of useful tools"
pi git openssh htop bmon nano os-prober openbsd-netcat ufw lsof vim wget snapper snap-pac rsync pacman-contrib openvpn
echo "#### Install Disk Utils"
pi gparted gptfdisk ntfs-3g util-linux dosfstools exfat-utils gnome-disk-utility

echo "#### Install Laptop energy management (TLP)"
pi tlp tlp-rdw

# Gaming specific
# pi lutris steam gamemode
# Wine, avoid if possible
# pi wine wine-gecko wine-mono winetrics
# Virtual machines, alternative to Virtualbox
# pi qemu virt-manager virt-viewer 
# Time Synchronisation
# pi ntp

echo "#### Install Fun packages"
pi neofetch cmatrix

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

echo "--------------------------------------------------------------------------"
echo "- Finished system installation"
echo "--------------------------------------------------------------------------"