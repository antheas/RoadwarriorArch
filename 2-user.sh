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

echo ""
echo "--------------------------------------------------------------------------"
echo "- Installing AUR & Software  "
echo "--------------------------------------------------------------------------"

echo "Installing YAY"
cd ~
rm -f -r yay
mkdir -p yay && cd yay
git clone "https://aur.archlinux.org/yay.git" .
makepkg -si --noconfirm
cd ..
rm -f -r yay
yay -Syu
ya () {
  yay -S --noconfirm $@
}

echo "#### Installing Fonts"
ya nerd-fonts-fira-code awesome-terminal-fonts
ya adobe-source-han-sans-cn-fonts adobe-source-han-sans-jp-fonts adobe-source-han-sans-kr-fonts adobe-source-sans-fonts
ya ttf-inconsolata ttf-indic-otf ttf-roboto ttf-windows

echo "#### Installing AUR utils"
ya tlpui inxi

echo "#### Installing Apps"
ya zotero xournalpp libreoffice-still
ya visual-studio-code-bin vivaldi solaar skypeforlinux-stable-bin
ya darktable inkscape rapid-photo-downloader gimp 

echo "#### Installing LaTeX"
ya texlive-most texlive-langgreek texlive-latexindent-meta

PKGS=(
'autojump'
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

echo "--------------------------------------------------------------------------"
echo "- Finished "
echo "--------------------------------------------------------------------------"
