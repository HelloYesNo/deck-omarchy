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

            # This is the Omarchy installation script content, run inside the container.

            # Set install mode to online since boot.sh is used for curl installations
            export OMARCHY_ONLINE_INSTALL=true

            # Omarchy ANSI art is skipped for silent install

            echo 'Running Omarchy installation script...'

            # The '--noconfirm' flag ensures pacman does not prompt for user input.
            # We use 'sudo' inside distrobox; the 'distrobox-enter' context typically handles sudo without a password.
            sudo pacman -Syu --noconfirm --needed git

            # Use custom repo if specified, otherwise default to basecamp/omarchy
            # OMARCHY_REPO='${OMARCHY_REPO:-HelloYesNo/omarchy}' # Defaulting to the repo from the script

            echo -e '\nCloning Omarchy from: https://github.com/HelloYesNo/omarchy.git'
            rm -rf ~/.local/share/omarchy/
            git clone 'https://github.com/HelloYesNo/omarchy.git' ~/.local/share/omarchy >/dev/null

            # Use custom branch if instructed, otherwise default to master
            OMARCHY_REF='master' # Defaulting to master
            if [[ \$OMARCHY_REF != 'master' ]]; then
                echo -e '\e[32mUsing branch: \$OMARCHY_REF\e[0m'
                cd ~/.local/share/omarchy
                git fetch origin '\${OMARCHY_REF}' && git checkout '\${OMARCHY_REF}'
                cd -
            fi

            echo -e '\nInstallation starting...'

            # The core install script. Since we already used --noconfirm on pacman,
            # and the rest of the script is git/echo/source, it should run non-interactively.
            source ~/.local/share/omarchy/install.sh
        "
        echo "Omarchy setup complete."
    else
        echo "Error: Failed to create or setup ${CONTAINER_NAME} Distrobox."
        exit 1
    fi
fi


## 2. Ensure the container is running (started)

# Use podman inspect to check the container's running status.
# If it's not running, start it.
if [[ $(podman inspect -f '{{.State.Running}}' ${CONTAINER_NAME} 2>/dev/null) != "true" ]]; then
    echo "Starting ${CONTAINER_NAME} Distrobox..."
    # 'distrobox start' is the correct command to start a Distrobox container
    distrobox start ${CONTAINER_NAME}

    if [ $? -ne 0 ]; then
        echo "Error: Failed to start ${CONTAINER_NAME} Distrobox."
        exit 1
    fi
fi


## 3. Launch the session

echo "Launching Omarchy Hyprland session..."
# 'distrobox enter' will now execute the command in the verified running container.
# Assuming the omarchy install sets up Hyprland and it's on the PATH inside the container
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
cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/wayland-sessions/plasma-steamos-wayland-oneshot.desktop
#
cp /usr/share/xsessions/omarchy-hyprland.desktop  /usr/share/wayland-sessions/plasma.desktop
