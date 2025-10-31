# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite:latest

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
#Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# Step 1: Install packages
# Using '\' for clean multi-line readability within one RUN instruction
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    dnf5 config-manager addrepo --overwrite --from-repofile=https://terra.fyralabs.com/terra.repo \
    && dnf5 -y install --allowerasing \
        git \
        meson \
        ninja-build \
        python3 \
        python3-pip \
        gcc \
        libgcc \
        dbus-devel \
        glib2-devel \
        python3-devel \
        util-linux \
        whiptail \
        fuzzel \
        libnotify \
        scdoc \
        mise \
        pacman \
        power-profiles-daemon \
        plocate \
    && pip install pyxdg dbus-python

# Step 2: Build and install uwsm
# Now that 'git' and other tools are installed, this step should work
RUN groupadd -r builder && useradd -r -g builder -m builder
# Switch all subsequent commands in this layer to the 'builder' user
USER builder 

# STEP 4/7: Build and install uwsm (as builder)
# Note: Since the user 'builder' won't have permission to write to /usr/local,
# we need to change the installation prefix to /home/builder/.local/
RUN mkdir -p /home/builder/uwsm \
    && git clone https://github.com/Vladimir-csp/uwsm.git /tmp/uwsm \
    && cd /tmp/uwsm \
    && git checkout $(git describe --tags --abbrev=0) \
    && meson setup --prefix=/home/builder/.local -Duuctl=enabled -Dfumon=enabled -Duwsm-app=enabled build \
    && ninja -C build \
    && ninja -C build install \
    && /home/builder/.local/bin/uwsm --version

USER root
WORKDIR /

RUN export OMARCHY_ONLINE_INSTALL=true \
    && mkdir -p /var/log \
    && mkdir -p /root/.config \
    && touch /etc/vconsole.conf \
    && mkdir -p /.local/share/omarchy/ \
    && git clone "https://github.com/HelloYesNo/omarchy.git" /.local/share/omarchy/ >/dev/null \
    && source /.local/share/omarchy/install.sh 

# RUN rm -f /var/log/*.log /var/log/*/*.log
# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
