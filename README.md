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
All installation scripts feature extensive comments and references to where each 
command was taken from.
At the same time, they were made to be customizable, so you can fork this repository
and customize it for yourself.

I use this script as is to setup my computers.
It installs all the packages I need.

Features include:
  - Tweaks
    - Both linux and linux-lts kernels installed
    - Microcode installed
    - Cron, bluetooth, networking, audio drivers, printing services
    - Silent Boot (UEFI logo retained until KDE lockscreen; no logs)
    - Make flags set for CPU cores
    - Parallel downloading for pacman
    - yay install
    - Passwordless sudo
    - Customizable locale/timezone
    - TLP install for power management
    - By default KDE with SDDM installed, one line change for something different
  - Security
    - Full Hard Drive Encryption with LUKS2 (including /boot)
    - TMP2 support for passwordless login (measured boot) that supports kernel updates
    - Kernel Updates protected by booting using a signed EFI stub and Secure Boot
    - Secure Boot support with key generation and signing handled
    - Automatic installation/signing of KeyTool and certs in EFI partition.
      - Painless install of keys in UEFI after install without USB stick.
    - Fully Functional unlocked and signed GRUB2 that can mount encrypted /boot
      for troubleshooting (password required; secure boot supported).
    - Custom image for GRUB2 that supports LUKS2 mounting and bundles all boot modules.
  - btrfs filesystem
    - Snapper support for both system directory and home directory with separate subvolumes
    - Sane snapper default configuration for both `/home` and system `/`
    - User inherits snapper volume management rights
    - Hibernation Support with encrypted swap file in btrfs
    - Script that generates btrfs alignment value for kernel resume cmd is built-in
    - Recovery script that can re-mount partitions from Arch installation media.
  - Hybrid BIOS/UEFI support
    - Unsigned GRUB2 executable installed on both BIOS partition and EFI partition
    - Boot on any computer by entering your disk encryption password
    - Enter password only on GRUB, special initramfs image with keyfile and
      kernel cmd handle unlocking volume the second time.
    - Commands provided to add EFI images to UEFI 
  - Proper Intel Integrated Graphics packages installed
    - Just modify your Chrome shortcut for video hardware acceleration
    - No tearing (kwin with OpenGL 3.1)
  - Separate script for most user space programs, which includes mine (`2-software.sh`)
    - Research programs: LaTeX, Zotero, Xournalpp, Libre Office
    - Photography/Design: wacom support, DarkTable, Rapid Photo Downloader, GIMP
    - Fonts, Dictionaries, etc
    - yay install
    - Some AUR programs that are installed with yay (sbupdate for secure boot efi, tlp UI)

What this script doesn't provide is dual boot support.
It is expected that you provide one full drive to Arch.
In my opinion, it's too risky to do dual boot on the same drive manually.
If you use two drives, you can use a UEFI entry to boot into Windows.

## Install Instructions  
> :warning: Unplug all other drives other than boot or disable them in UEFI 
> before proceeding to running this script to avoid mistakes.
## VirtualBox Testing
There's 0% chance this script will work as is or be fit to your requirements.
Therefore, before installing it on your computer you should try it on a 
Virtual Machine.
Start by installing VirtualBox and creating an Arch VM with a thin (lazy allocated) 50GB disk.
Arch/Manjaro commands:
``` bash
yay -S virtualbox
sudo vboxreload
```
Clone/Fork this repository and open it with your favorite editor (such as VSCode):
``` bash
git clone https://github.com/antheas/RoadwarriorArch
code RoadwarriorArch
```
Mount the git directory as a read only `Shared Folder` in the Arch VM under
`/root/rw`.

Mount the Arch Installation ISO (<https://archlinux.org/download/>) as the VM boot
drive and launch the VM.

Follow the installation instructions below.
Be sure to test the script using both BIOS and UEFI virtualbox modes.
Secure Boot is not available, so testing that will have to be done using your laptop.

## Optional SSH connection
Typing within the boot VM is tiring.
I'd recommend enabling SSH for the boot iso and connecting into it using
your favorite terminal.
To do this: 
  - Create a host-only network and add it as a secondary one to the VM.
  - Restart the VM and set a password for root using `passwd`
  - Use `ip address` to grab the VM IP
  - Connect to your VM by typing `ssh root@<ip>` (sshd is enabled by default in Arch ISO)
  - You will be prompted to accept the fingerprint and connect.
  - If restarting and getting the same ip, the fingerprint will be different so you
    will be denied access. Use `ssh-keygen -R <ip>` to clear the fingerprint for that IP.
  - You can now use your riced terminal to install Arch!

## Installation Steps after Boot
After booting into your virtualbox, the command `ls ~/rw` will return the following
```
0-preinstall.sh  1-setup.sh  2-software.sh  3-dotfiles.sh  install.example.conf  
LICENSE  physical.c  README.md  rw-install.sh  rw-rescue.sh  sbupdate.conf  snapper_sample.conf
```

`cd` into `~/rw` and create your `install.conf` file.
``` bash
cd ~/rw
cp install.example.conf install.conf
nano install.conf
```

Afterwards, run `./rw-install.sh`
``` bash
bash rw-install.sh
```
You will be asked a couple of format related question and Arch will be installed.

## Installation details
This repository is made up of the following scripts:
  - **0-preinstall.sh**: formats the drive using LUKS2 and bootstraps Arch using install media
  - **1-setup.sh**: runs within arch-chroot and installs the desktop environment
    and configures the main OS (can be run multiple times to refresh system)
  - System is bootable after running those two scripts
  - **2-software.sh**: installs yay, sbupdate (installs efi executables), and a 
    lot of large programs, skip for testing.
    Runs using created user, non-root
  - **3-dotfiles.sh**: is empty, use it to install user configuration
  - **rw-install.sh**: runs 0-preinstall.sh, 1-setup.sh, 2-software.sh, 3-dotfiles.sh
    in order. It prompts before running 2-software.sh, 3-dotfiles.sh, so you can skip those
    for testing.
  - **rw-rescue.sh**: unlocks and remounts a drive that was created using `0-preinstall.sh`
    into `/mnt`, so you can continue installation after restarting or diagnose
    the system. 

Look through them and customize them to taste.

`rw-install.sh`, `0-preinstall.sh` can be run multiple times without restarting
and will clean the drive each time, so if something fails you can just re-run
them until it works.

`1-setup.sh` does not damage an already installed system and can be re-run after
changing to update that system, after mounting with `rw-rescue.sh`.

## Installing into your Laptop
It's recommended you have access to a secondary computer during this setup.
Connecting through the working computer to your laptop using `ssh` will allow
copy, pasting commands and make looking at documentation easier.

### Boot ISO into USB
Install the Arch installation media into a USB drive.
You can try Ventoy.
If on Linux, I found `gnome-disk-utility` to be the best for formatting USB drives, 
even if using KDE.
If on Windows, try Etcher.

## Connecting to WIFI
Use iwctl to connect to WIFI
``` bash
iwctl
> device list
> station [name] scan
> station [name] get-networks
> station [name] connect [ssid]

# Or if you're feeling lucky after rebooting 20 times
iwctl station [name] connect [ssid]
# will work on its own 50% of the time
# you might need to run first:
iwctl station [name] scan

# Test
ping google.com
```

## Connecting over SSH
Find your ip address and set a root password:
``` bash
ip address
passwd
```

Over at your other computer (same private network) type:
``` bash
ssh root@<ip>
```
Follow the VirtualBox SSH guide for details.

## Transfering Roadwarrior files
You don't have the customized Roadwarrior instance on the laptop yet, so copy it
using `scp`

``` bash
scp -r ../RoadwarriorArch root@<ip>:rw
```

Or, copy over to a USB and mount it in Arch ISO using:
``` bash
# Identify usb drive name
lsblk
# Mount on ~/usb
mkdir ~/usb
mount /dev/<usb> ~/usb
cd ~/usb/RoadwarriorArch
```

## Installation
`cd` into the code directory and run `./rw-install.sh`
``` bash
bash rw-install.sh
```
You will be prompted for which disk to format, whether to install EFI bios entries
and whether to continue with `2-software.sh`, `3-dotfiles.sh`.
First time, do a base install and skip the rest.
After verifying the system boots properly, execute the whole setup.

## Secure Boot and TMP
You now have a working system!
Which that boots with GRUB2/EFI stubs and asks for a password.
Next step is to enable UEFI Secure boot and add your keys to it.

Read `1-setup.sh` for detailed instructions.

The signing happens using a package from AUR that's named `sbupdate`, so if you haven't
run `2-software.sh` you won't have the signed executables yet.
Run it first.

### Using the built-in Key Manager
If you have a recent laptop, you can just login into UEFI and add your
keys using the built in key manager.
You only need to add the `db` key when doing this.
Your key certificates (public portion only) where copied to `efi/keys`, no USB 
stick necessary.
This is what was used to sign all your executables and will allow booting with
secure boot on.

Messing with the other keys can cause some firmware issues in some laptops
(such as the graphics card being disabled during boot so you can't use the built
in display to access the BIOS), so avoid it.
If you worry that somebody can circuimvent the TPM protection by booting an executable
that uses another key, this is not the case.
A properly configured TPM will roll all keys used when booting to PCR 7, so if
a differently signed executable is introduced, PCR 7 will be corrupted and 
unlocking your drive will fail.

### Using KeyTool
If your laptop doesn't include a key manager, you can use `KeyTool`.
Certain laptops (such as Thinkpad T14 gen 1) may be bricked by using it, so avoid
it if possible.
It worked fine for my Thinkpad X280.

First, switch your laptop's Secure Boot into setup mode.
This will clear the Platform Key (PK) that is used to validate
Key Exchange Keys (KEK), which are used to validate Whitelist Database (DB) keys.
Since PK (root of trust) is removed, your laptop trusts code signed with any key 
and key amendments signed with any key.
So, you can now boot into `KeyTool` and install your `DB` key.

Keytool was installed and signed by the installation scripts in `efi/EFI/Keytool.efi`
and a boot entry was created for it, so boot using it.

First, backup all of the platform keys, especially if your UEFI doesn't have a
reset to factory option.

Your key certificates (public portion only) where copied to `efi/keys`, no USB 
stick necessary.

Then, install your `DB` (`efi/keys/DB.auth`) key.

Optionally, install your `KEK`, which would allow amending `DB`.

Lastly, install either your `PK` key or the original one to lock Secure Boot.

Since you can always re-enter setup mode manually, there's no point in obsessing 
over installing all the keys or in what order.
They are designed that way so that manufacturers can apply OTA updates to normal
end-users.

Reboot and boot into `Arch - Linux` with Secure Boot on.

Success!

## Enable TMP2 Support
After enabling secure boot and restarting a few times to make sure it works you
can move on to enabling TMP2 support.
Start by booting using either `Arch - Linux` or `Arch - Linux LTS`.

The kernel header that enables TMP2 unlock is already installed for you in the 
`EFI stubs`.

All you need to do is add a TPM entry to your drive's LUKS2 header.
Start by editing your `~/.bashrc` or `~/.zshrc` and adding the following.

``` bash
# TPM PCRS
# 0 UEFI 2 KERNEL 4 BOOTLOADER 5 PARTITION TABLE 7 SECURE BOOT (grub: 8 KERNEL CMD 9 KERNEL IMG)
# https://www.gnu.org/software/grub/manual/grub/grub.html#Measured-Boot
# https://threat.tevora.com/secure-boot-tpm-2/
PCRS="0+2+3+7+8"

# Of course systemd-cryptenroll doesn't support key files, so generate a keyphrase
# and use that when updating the tpm to avoid the entering password
alias tpmk="sudo bash -c 'systemd-cryptenroll --recovery-key \$(blkid | grep crypto_LUKS | egrep -o \"^\/dev\/[a-zA-Z0-9]+\") > /crypt/systemd.key && chmod 700 /crypt/systemd.key'"
# cryptsetup luksKillSlot /dev/... n kills slot n
# cryptsetup luksDump /dev/... shows info about device (and json tokens)

# In case you wipe a tpm slot using cryptsetup luksKillSlot
# systemd-cryptenroll will report an error:
# Failed to determine keyslot of JSON token: Wrong medium type
# to fix, remove the leftover JSON tokens
# cryptsetup token remove --token-id 0 /dev/...

# tpmu updates the TPM key (removes the current ones and adds a new one)
# tpma adds a tpm key without removing the current ones (multiple kernels etc)
# tpmc clears the TPM keys (think going through airport security)
alias tpmu="sudo bash -c 'PASSWORD=\"\$(cat /crypt/systemd.key)\" systemd-cryptenroll --tpm2-device=auto --wipe-slot=tpm2 --tpm2-pcrs=$PCRS \$(blkid | grep crypto_LUKS | egrep -o \"^\/dev\/[a-zA-Z0-9]+\")'"
alias tpma="sudo bash -c 'PASSWORD=\"\$(cat /crypt/systemd.key)\" systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=$PCRS \$(blkid | grep crypto_LUKS | egrep -o \"^\/dev\/[a-zA-Z0-9]+\")'"
alias tpmc="sudo bash -c 'PASSWORD=\"\$(cat /crypt/systemd.key)\" systemd-cryptenroll --wipe-slot=tpm2 \$(blkid | grep crypto_LUKS | egrep -o \"^\/dev\/[a-zA-Z0-9]+\")'"
```

Restart your bash shell or launch a new one.
``` bash
zsh
# or
bash
```

Then, run the command `tpmk` and enter your drive password.
This command will create a recovery key (in `/crypt/systemd.key` and slot 2) that's 
supported by `systemd-cryptenroll` and will be used by the latter commands so 
that you don't have to re-enter your password every time you change something.

Then, type `tpmu` to enroll a key into your LUKS header that uses the `PCRs`
0, 2, 3, 7, 8.

Why 8? Because your signed GRUB will change it when booting, preventing messing
with GRUB configuration using it to mount your volume.
7 Verifies secure boot hasn't been tampered with and 0,2,3 validate your UEFI
image.
You can add PCR 1 to prevent UEFI configuration changes.

Reboot and hopefully you won't be asked for a password!

By typing `tpmc` you can wipe the TPM2 header slots.
Do this and shutdown before passing through security or leaving your laptop into
storage.
You will be asked for a password next time you boot.
Your laptop is now just as secure as not using TPM2 and not 
vulnerable to cold boot attacks.

## Skipping SDDM
SDDM doesn't use your xrandr configuration, so depending on your monitor setup
you might have messed up resolutions/display locations.
It also doesn't transfer your KDE theme correctly.
And, before you log in with your password your services aren't starting, so it
extends your boot time.

So, disable it!

Head over to `System Settings > Startup and Shutdown > Login Screen (SDDM) > Behavior` 
and tick `Automatically log in:` as your user with session `Plasma (X11)`.
As well as `Log in again immediately after logging off`.

But, what about security? 
Your laptop boots in without a password and logs in automatically now.

Add `DESKTOP_LOCKED=1` to `~/.pam_environment` (doesn't exist by default).
``` bash
echo "DESKTOP_LOCKED=1" > ~/.pam_environment
```

This will cause KDE to lock your user the moment you log in.

This way, your services will get loaded as soon as you boot, waiting for you to
put your password, your `kscreen/xrandr` configuration will be loaded having
your monitors appear correctly, and your lockscreen theme will be used!

With this configuration, my laptop boots within 20 seconds and is ready to use
the moment I enter my password.

## Installing dotfiles (configuration)
The installation steps are over and now you have fully functional Arch install 
with state-of-the-art tweaks and an encryption scheme that rivals bitlocker in 
terms of convenience.

Congratulations!

Feel free to install your dotfiles the way you prefer, or copy over your user
folder from another computer.

> TODO: Release my own dotfiles.
## Credits
- Chris Titus' Arch Titus script that was used as a base. Credits from those:
  - Original packages script was a post install cleanup script called ArchMatic located here: https://github.com/rickellis/ArchMatic
  - Thank you to all the folks that helped during the creation from YouTube Chat! Here are all those Livestreams showing the creation: <https://www.youtube.com/watch?v=IkMCtkDIhe8&list=PLc7fktTRMBowNaBTsDHlL6X3P3ViX3tYg>
