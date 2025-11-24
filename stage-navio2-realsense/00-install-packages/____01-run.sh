#!/bin/bash -e

# Ensure qemu static binary exists
if [ ! -f "$ROOTFS_DIR/usr/bin/qemu-aarch64-static" ]; then
    echo "Copying qemu-aarch64-static to chroot"
    cp /usr/bin/qemu-aarch64-static "$ROOTFS_DIR/usr/bin/"
fi

# Mount pseudo-filesystems for chroot
# mount --bind /dev  "$ROOTFS_DIR/dev"
# mount --bind /sys  "$ROOTFS_DIR/sys"
# mount --bind /proc "$ROOTFS_DIR/proc"
# mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"

# Install dependencies via on_chroot
on_chroot << 'EOF'
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    dkms \
    raspberrypi-kernel-headers \
    i2c-tools \
    build-essential \
    ccache \
    g++ \
    python3 \
    python3-pip \
    python3-dev \
    python3-numpy \
    python3-opencv \
    curl \
    wget \
    ca-certificates \
    device-tree-compiler \
    libssl-dev \
    libusb-1.0-0-dev \
    pkg-config \
    libgtk-3-dev \
    libglfw3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    cmake \
    libudev-dev
EOF

echo "Dependencies installed"
DEPS

