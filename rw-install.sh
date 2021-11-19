#!/bin/bash
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
set -e
bash ${SCRIPT_DIR}/0-preinstall.sh

# Copy repo to root
rm -R -f /mnt/root/install-script
cp -R ${SCRIPT_DIR} /mnt/root/install-script

arch-chroot /mnt /root/install-script/1-setup.sh

# Copy repo to user and give perms for it
source /mnt/root/install-script/install.conf
arch-chroot /mnt rm -R -f /home/$username/install-script
arch-chroot /mnt cp -R /root/install-script /home/$username/install-script
arch-chroot /mnt chown -R $username /home/$username/install-script

arch-chroot /mnt /usr/bin/runuser -u $username -- /home/$username/install-script/2-user.sh