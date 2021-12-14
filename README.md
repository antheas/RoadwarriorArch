``` bash
#----------------------------------------------------------------------------------
#  __________                 ._____      __                    .__              
#  \______   \ _________    __| _/  \    /  \____ ______________|__| ___________ 
#   |       _//  _ \__  \  / __ |\   \/\/   |__  \\_  __ \_  __ \  |/  _ \_  __ \
#   |    |   (  <_> ) __ \/ /_/ | \        / / __ \|  | \/|  | \/  (  <_> )  | \/
#   |____|_  /\____(____  |____ |  \__/\  / (____  /__|   |__|  |__|\____/|__|   
#          \/           \/     \/       \/       \/                              
#----------------------------------------------------------------------------------
```

This repository contains a collection of scripts that will install Arch and include
all of the relevant features for a laptop user (i.e. a roadwarrior; RoadwarriorArch).
All installation scripts feature extensive comments and references to where they
were each command was taken from.
At the same time, they were made to be customizable, so you can fork this repository
and customize it for yourself.

Those include:
  - Security
    - Full Hard Drive Encryption with LUKS2
    - TMP2 support for passwordless login (measured boot) that supports kernel updates
    - Kernel Updates protected by booting using a signed EFI stub and Secureboot
    - Secure Boot support with key generation and signing handled
    - Automatic installation/signing of KeyTool and certs in EFI partition.
      Painless install of keys in UEFI.
    - Fully Functional unlocked and signed GRUB2 that can mount encrypted /boot
      for troubleshooting (password required).
  - Btrfs filesystem
    - Hibernation Support with encrypted swap file in btrfs
    - Script that generates Btrfs alignment value for kernel cmd is built-in
    - Snapper support for both system directory and home directory with separate subvolumes
  - Tweaks
    - Silent Boot (UEFI logo retained until KDE lockscreen; no logs)
    - Make flags set for CPU cores
    - Customizable locale/timezone
  - Hybrid BIOS/UEFI support
    - Unsigned GRUB2 executable installed on both BIOS partition and EFI partition
    - Boot on any computer by entering your Disk password
    - Enter password only on GRUB, special initramfs image with keyfile and
      kernel cmd unlock volume the second time.
    - Commands provided to add EFI images to UEFI 
  - Proper Intel Integrated Graphics packages installed
    - Just modify your Chrome shortcut for video hardware acceleration
    - No tearing (kwin with OpenGL 3.1)

## Create Arch ISO or Use Image

Download ArchISO from <https://archlinux.org/download/> and put on a USB drive with Ventoy or Etcher

If you don't want to build using this script I did create an image @ <https://www.christitus.com/arch-titus>

## Boot Arch ISO

From initial Prompt type the following commands:

```
pacman -Sy git
git clone https://github.com/ChrisTitusTech/ArchTitus
cd ArchTitus
./archtitus.sh
```

### System Description
This is completely automated arch install of the KDE desktop environment on arch using all the packages I use on a daily basis. 

## Troubleshooting

__[Arch Linux Installation Guide](https://github.com/rickellis/Arch-Linux-Install-Guide)__

### No Wifi

#1: Run `iwctl`

#2: Run `device list`, and find your device name.

#3: Run `station [device name] scan`

#4: Run `station [device name] get-networks`

#5: Find your network, and run `station [device name] connect [network name]`, enter your password and run `exit`. You can test if you have internet connection by running `ping google.com`. 

## Credits

- Original packages script was a post install cleanup script called ArchMatic located here: https://github.com/rickellis/ArchMatic
- Thank you to all the folks that helped during the creation from YouTube Chat! Here are all those Livestreams showing the creation: <https://www.youtube.com/watch?v=IkMCtkDIhe8&list=PLc7fktTRMBowNaBTsDHlL6X3P3ViX3tYg>
