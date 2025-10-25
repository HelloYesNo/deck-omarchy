#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
# dnf5 -y remove plasma-workspace plasma-* kde-*

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
systemctl enable podman.socket

# --- FIX FOR DISTROBOX CREATION ERROR ---
# Distrobox creation fails during the image build because the build environment
# (a temporary container) lacks the necessary host-like filesystem structure.
# Instead, we install a script that the user's desktop session will run
# to create the Distrobox *after* booting the image for the first time.
# ------------------------------------------

# 1. Create the setup and launch script
# This script creates the Distrobox and installs Omarchy inside it, but only if it doesn't already exist.
cat << 'EOF_LAUNCHER' > /usr/bin/omarchy-setup-and-launch.sh
#!/bin/bash

CONTAINER_NAME="omarchy"
IMAGE_NAME="archlinux:latest"

# 1. Check if the container exists. If not, create and configure it.
if ! podman container exists ${CONTAINER_NAME}; then
    echo "Creating ${CONTAINER_NAME} Distrobox environment..."

    # Use 'distrobox-create' to build the container
    distrobox-create ${CONTAINER_NAME} --init --image ${IMAGE_NAME} --yes

    if [ $? -eq 0 ]; then
        echo "Entering container to run Omarchy installation..."
        # Use 'distrobox-enter' to run the installation script inside the new container
        distrobox-enter ${CONTAINER_NAME} -- bash -c "
            set -euo pipefail
            echo 'Running Omarchy installation script...'
            curl -fsSL https://omarchy.org/install | bash
        "
        echo "Omarchy setup complete."
    else
        echo "Error: Failed to create or setup ${CONTAINER_NAME} Distrobox."
        exit 1
    fi
fi

# 2. Launch the session
echo "Launching Omarchy Hyprland session..."
# Assuming the omarchy install sets up Hyprland and it's on the PATH inside the container
# If Omarchy has a specific session wrapper, replace 'hyprland' below.
exec distrobox enter ${CONTAINER_NAME} -- hyprland

EOF_LAUNCHER

# Make the setup script executable
chmod +x /usr/bin/omarchy-setup-and-launch.sh

# 2. Create the desktop file that points to the launcher script
# This allows the user to select the "Omarchy Hyprland" session at the login screen.
cat << 'EOF_DESKTOP' > /usr/share/xsessions/omarchy-hyprland.desktop
[Desktop Entry]
Name=Omarchy Hyprland (Distrobox)
Comment=Launch the Omarchy Hyprland environment inside a Distrobox container
Exec=/usr/bin/omarchy-setup-and-launch.sh
Type=Application
EOF_DESKTOP

cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/wayland-sessions/omarchy-hyprland.desktop

# cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/xsessions/plasma-steamos-oneshot.desktop
#
# cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/wayland-sessions/plasma-steamos-wayland-oneshot.desktop
#
# cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/wayland-sessions/plasma.desktop
