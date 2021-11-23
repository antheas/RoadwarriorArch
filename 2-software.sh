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
sleep 2
set -e

echo ""
echo "--------------------------------------------------------------------------"
echo "- Installing AUR & Software  "
echo "--------------------------------------------------------------------------"

# Only create starting and ending snapshots
# chroot doesn't have dbus
# no-dbus doesn't allow arguments
sudo snapper --no-dbus -c root create #--description \"Fresh Install\"
sudo snapper --no-dbus -c home create #--description \"Fresh Install\"

if [ -z "$(pacman -Q yay 2> /dev/null)" ]; then
  echo "Installing YAY"
  cd ~
  rm -f -r yay
  mkdir -p yay && cd yay
  git clone "https://aur.archlinux.org/yay.git" .
  makepkg -si --noconfirm
  cd ..
  rm -f -r yay
  yay -Syu
else
  echo "YAY is currently installed"
fi

ya () {
  yay -S --noconfirm $@
}

echo "#### Installing Fonts"
ya nerd-fonts-fira-code awesome-terminal-fonts
ya adobe-source-han-sans-cn-fonts adobe-source-han-sans-jp-fonts adobe-source-han-sans-kr-fonts adobe-source-sans-fonts
ya ttf-inconsolata ttf-indic-otf ttf-roboto ttf-windows

echo "#### Installing AUR utils"
ya tlpui inxi snapper-gui-git

echo "#### Installing Apps"
ya zotero xournalpp libreoffice-still
ya vivaldi vivaldi-ffmpeg-codecs
# vs code requires gnome-keyring
ya visual-studio-code-bin solaar skypeforlinux-stable-bin keepassxc gnome-keyring
ya darktable inkscape rapid-photo-downloader gimp 

echo "#### Installing Wacom Support"
ya kcm-wacomtablet xf86-input-wacom

echo "#### Installing LaTeX"
ya texlive-most texlive-langgreek texlive-latexindent-meta

PKGS=(
# 'autojump'
# 'lightly-git'
# 'lightlyshaders-git'
# 'mangohud' # Gaming FPS Counter
# 'mangohud-common'
'ocs-url' # install packages from websites
'snapper-gui-git'
'konsave'
)

for PKG in "${PKGS[@]}"; do
    ya $PKG
done

# ya snap-pac

sudo snapper --no-dbus -c root create #--description \"Post Software\"
sudo snapper --no-dbus -c home create #--description \"Post Software\"

echo "--------------------------------------------------------------------------"
echo "- Finished "
echo "--------------------------------------------------------------------------"
