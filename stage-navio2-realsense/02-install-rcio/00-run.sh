#!/bin/bash -e

# Install RCIO DKMS module for Navio2 inside the chroot environment

if [ ! -f "$ROOTFS_DIR/usr/bin/qemu-aarch64-static" ]; then
    echo "Copying qemu-aarch64-static to chroot"
    cp /usr/bin/qemu-aarch64-static "$ROOTFS_DIR/usr/bin/"
fi

# Mount pseudo-filesystems for chroot
mount --bind /dev  "$ROOTFS_DIR/dev"
mount --bind /sys  "$ROOTFS_DIR/sys"
mount --bind /proc "$ROOTFS_DIR/proc"
mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"



on_chroot << 'EOF'
set -e

ln -sf /usr/bin/dtc /usr/local/bin/dtc

# Ensure DKMS is installed
apt-get update
apt-get install -y dkms git

# Clone RCIO DKMS repository if missing
if [ ! -d /usr/src/rcio-dkms ]; then
    git clone https://github.com/emlid/rcio-dkms.git /usr/src/rcio-dkms
fi

cd /usr/src/rcio-dkms

# Get version from dkms.conf
VER=$(awk -F'[" ]' '/PACKAGE_VERSION/{print $3}' dkms.conf)
echo "Installing RCIO DKMS version: $VER"

# Register, build, and install the kernel module
dkms add /usr/src/rcio-dkms || true
dkms build rcio/$VER
dkms install rcio/$VER

# Auto-load modules at boot
cat << 'MODPROBE' > /etc/modules-load.d/rcio.conf
rcio_core
rcio_spi
MODPROBE

echo "RCIO DKMS module installation complete"
EOF

echo "RCIO installation script done (Pi-gen stage)"
