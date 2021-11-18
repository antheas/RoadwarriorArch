#!/usr/bin/env bash
#----------------------------------------------------------------------------------
#  __________                 ._____      __                    .__              
#  \______   \ _________    __| _/  \    /  \____ ______________|__| ___________ 
#   |       _//  _ \__  \  / __ |\   \/\/   |__  \\_  __ \_  __ \  |/  _ \_  __ \
#   |    |   (  <_> ) __ \/ /_/ | \        / / __ \|  | \/|  | \/  (  <_> )  | \/
#   |____|_  /\____(____  |____ |  \__/\  / (____  /__|   |__|  |__|\____/|__|   
#          \/           \/     \/       \/       \/                              
#----------------------------------------------------------------------------------

echo -e "----------------------------------------------------------------------------------"
echo -e "  __________                 ._____      __                    .__                "
echo -e "  \\______   \\ _________    __| _/  \\    /  \\____ ______________|__| ___________   "
echo -e "   |       _//  _ \\__  \\  / __ |\\   \\/\\/   |__  \\\\_  __ \\_  __ \\  |/  _ \\_  __ \\  "
echo -e "   |    |   (  <_> ) __ \\/ /_/ | \\        / / __ \\|  | \\/|  | \\/  (  <_> )  | \\/  "
echo -e "   |____|_  /\\____(____  |____ |  \\__/\\  / (____  /__|   |__|  |__|\\____/|__|     "
echo -e "          \\/           \\/     \\/       \\/       \\/                                "
echo -e "----------------------------------------------------------------------------------"
sleep 3

echo ""
echo "--------------------------------------------------------------------------"
echo "- Network Setup   "
echo "--------------------------------------------------------------------------"
pacman -S networkmanager dhclient --noconfirm --needed
systemctl enable --now NetworkManager

iso=$(curl -4 ifconfig.co/country-iso)
echo "--------------------------------------------------------------------------"
echo "- Setting $iso up mirrors for optimal download         "
echo "--------------------------------------------------------------------------"
# Parallel downloads
sed -i 's/^#Para/Para/' /etc/pacman.conf
pacman -S --noconfirm reflector
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
echo "- Setup Language to US and set locale       "
echo "--------------------------------------------------------------------------"
source install.conf
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
timedatectl --no-ask-password set-timezone America/Chicago
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"

# Set keymaps
localectl --no-ask-password set-keymap us

# Add sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

# Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

# Graphics Drivers find and install
if lspci | grep -E "NVIDIA|GeForce"; then
  # FIXME: add optimus setup
  pacman -S nvidia --noconfirm --needed
  nvidia-xconfig
elif lspci | grep -E "Radeon"; then
  pacman -S xf86-video-amdgpu --noconfirm --needed
elif lspci | grep -E "Integrated Graphics Controller"; then
  pacman -S --needed --noconfirm intel-media-driver libva-utils intel-gpu-tools
# elif lspci | grep -E "Integrated Graphics Controller"; then
#   pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils --needed --noconfirm
fi

echo "--------------------------------------------------------------------------"
echo "- Installing base system packages       "
echo "--------------------------------------------------------------------------"
alias pi="pacman -S --noconfirm --needed"

echo "Install mesa and xorg to power display"
pi mesa xorg xorg-server xorg-apps xorg-drivers xorg-xkill xorg-xinit
echo "Install plasma group + kde, desktop environment, sddm login"
pi plasma kde-utilities kde-system zeroconf-ioslave sddm
echo "Install a subsection of kde-applications, which is too large"
pi gwenview okular spectacle

echo "Install Compression Utils"
pi ark zip unzip unrar p7zip lzop 
echo "Install Terminal Utils (use zsh!)"
pi zsh bash-completion
# Available with oh-my-zsh, install from there
# 'zsh-syntax-highlighting' 
# 'zsh-autosuggestions'

echo "Install audio packages and manager"
pi alsa-plugins alsa-tools alsa-utils                         
pi pulseaudio pulseaudio-alsa pulseaudio-Bluetooth
echo "Install Bluetooth provider"
pi bluez bluez-libs bluez-utils                    

echo "Install Fuse mounts, mount GDrive, OneDrive etc with rclone"
pi rclone fuse2 fuse3
echo "Install Python"
pi python python2 python-pip python2-pip

echo "Install a collection of useful tools"
pi git openssh htop bmon nano os-prober openbsd-netcat inxi ufw lsof vim wget snapper rsync ntp pacman-contrib openvpn
echo "Install Disk Utils"
pi gparted gptfdisk ntfs-3g util-linux dosfstools exfat-utils gnome-disk-utility

echo "Install Laptop energy management (TLP)"
pi tlp tlp-drw tlpui

# Gaming specific
# pi lutris steam gamemode
# Wine, avoid if possible
# pi wine wine-gecko wine-mono winetrics
# Virtual machines, alternative to Virtualbox
# pi qemu virt-manager virt-viewer 

echo "Install Fun packages"
pi neofetch cmatrix kitty

echo "Install Misc Packages"
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
echo "- Creating user"
echo "--------------------------------------------------------------------------"
if ! source install.conf; then
  read -p "Enter username: " username
  read -p "Enter password: " password
  read -p "Enter hostname: " hostname
  echo "username=$username\npassword=$password\nhostname=$hostname" >> install.conf
fi

if [ $(whoami) = "root"  ]; then
  useradd -m -G wheel -s /bin/bash $username 
  echo "$password" | passwd $username --stdin
  cp -R /root/ArchTitus /home/$username/
  chown -R $username: /home/$username/ArchTitus
  echo $hostname > /etc/hostname
fi

echo "--------------------------------------------------------------------------"
echo "- GRUB BIOS Bootloader Install&Check"
echo "--------------------------------------------------------------------------"
# Has to be in chroot to run correctly, besides grub isn't available in the iso.
grub-mkconfig -o /boot/grub/grub.cfg
grub-install --target=x86_64-efi --bootloader-id=RoadwarriorArch ${DISK}

echo "--------------------------------------------------------------------------"
echo "- Enable Essential Services "
echo "--------------------------------------------------------------------------"
systemctl enable sddm.service
systemctl enable cups.service
systemctl enable cronie
ntpd -qg
systemctl enable ntpd.service
# systemctl disable dhcpcd.service
# systemctl stop dhcpcd.service
systemctl enable NetworkManager
systemctl enable bluetooth

echo "--------------------------------------------------------------------------"
echo "- Finished system installation"
echo "--------------------------------------------------------------------------"