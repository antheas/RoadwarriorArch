#!/bin/bash
bash 0-preinstall.sh

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cp -R ${SCRIPT_DIR} /mnt/root/install-script

arch-chroot /mnt /root/install-script/1-setup.sh
source /mnt/root/install-script/install.conf
arch-chroot /mnt /usr/bin/runuser -u $username -- /home/$username/install-script/2-user.sh