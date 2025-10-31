# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM quay.io/fedora/fedora-bootc:42

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
    dnf5 -y install \
        git \
        meson \
        ninja-build \
        python3 \
        python3-pip \
        gcc \
        libgcc \
        dbus-devel \
    && pip install pyxdg dbus-python

# Step 2: Build and install uwsm
# Now that 'git' and other tools are installed, this step should work
RUN mkdir -p /uwsm \
    && git clone https://github.com/Vladimir-csp/uwsm.git /uwsm \
    && cd /uwsm \
    && git checkout $(git describe --tags --abbrev=0) \
    && meson setup --prefix=/usr/local -Duuctl=enabled -Dfumon=enabled -Duwsm-app=enabled build \
    && chown -R 0:0 /usr/local \
    && mkdir -p /usr/local/share /usr/local/bin /usr/local/lib \
    && ninja -C build \
    && ninja -C build install \
    && uwsm --version

RUN rm /opt && mkdir /opt

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
