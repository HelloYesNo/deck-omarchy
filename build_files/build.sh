#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
# dnf5 -y remove plasma-workspace plasma-* kde-*
dnf5 config-manager addrepo --overwrite --from-repofile=https://terra.fyralabs.com/terra.repo
dnf5 install -y git


# This is the Omarchy installation script content, run inside the container.

# Set install mode to online since boot.sh is used for curl installations
export OMARCHY_ONLINE_INSTALL=true

# Omarchy ANSI art is skipped for silent install

echo 'Running Omarchy installation script...'
# Use custom repo if specified, otherwise default to basecamp/omarchy
# OMARCHY_REPO='${OMARCHY_REPO:-HelloYesNo/omarchy}' # Defaulting to the repo from the script

echo -e '\nCloning Omarchy from: https://github.com/HelloYesNo/omarchy.git'
# rm -rf /root/.local/share/omarchy/
mkdir -p /.local/share/omarchy/
git clone "https://github.com/HelloYesNo/omarchy.git" /.local/share/omarchy/ >/dev/null

# Use custom branch if instructed, otherwise default to master
OMARCHY_REF='master' # Defaulting to master
if [[ \$OMARCHY_REF != 'master' ]]; then
    echo -e '\e[32mUsing branch: \$OMARCHY_REF\e[0m'
    cd "$HOME/.local/share/omarchy/"
    git fetch origin 'master' && git checkout 'master'
    cd -
fi

echo -e '\nInstallation starting...'

# The core install script. Since we already used --noconfirm on pacman,
# and the rest of the script is git/echo/source, it should run non-interactively.
source "$HOME/.local/share/omarchy/install.sh"
echo "Omarchy setup complete."





# 2. Create the desktop file that points to the launcher script
# This allows the user to select the "Omarchy Hyprland" session at the login screen.
cat << 'EOF_DESKTOP' > /usr/share/xsessions/omarchy-hyprland.desktop
[Desktop Entry]
Name=Omarchy Hyprland (Distrobox)
Comment=Launch the Omarchy Hyprland environment inside a Distrobox container
Exec=Hyprland
Type=Application
EOF_DESKTOP

cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/wayland-sessions/omarchy-hyprland.desktop

# cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/xsessions/plasma-steamos-oneshot.desktop
#
# cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/wayland-sessions/plasma-steamos-wayland-oneshot.desktop
#
# cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/wayland-sessions/plasma.desktop

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
systemctl enable podman.socket
