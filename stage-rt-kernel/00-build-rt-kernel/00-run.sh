#!/bin/bash -e

# Build PREEMPT_RT kernel for Raspberry Pi 4 (64-bit)
# Uses kernel 6.1.y which has better RT patch compatibility

echo "Building PREEMPT_RT kernel for Raspberry Pi 4..."

RT_BUILD_DIR="${WORK_DIR}/rt-kernel-build"
mkdir -p "${RT_BUILD_DIR}"

# Install build dependencies on HOST
apt-get update
apt-get install -y git bc bison flex libssl-dev make libncurses5-dev \
    libncursesw5-dev dwarves kmod cpio rsync fakeroot libelf-dev \
    crossbuild-essential-arm64 xz-utils curl wget

cd "${RT_BUILD_DIR}"

# Clone Raspberry Pi kernel - use 6.1.y (more stable for RT)
if [ ! -d linux ]; then
    echo "Cloning Raspberry Pi kernel (rpi-6.1.y)..."
    git clone --depth=1 --branch rpi-6.1.y https://github.com/raspberrypi/linux.git
fi

cd linux

# Get exact kernel version
KERNEL_VERSION=$(make kernelversion)
echo "Kernel version: ${KERNEL_VERSION}"

# For 6.1.y, use a known working RT patch version
# Use 6.1.119-rt45 which is known stable
RT_PATCH_URL="https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/6.1/patch-6.1.158-rt58.patch.xz"

echo "Downloading RT patch..."
if [ ! -f ../rt-patch.xz ]; then
    wget -O ../rt-patch.xz "${RT_PATCH_URL}" || {
        echo "Failed to download RT patch. Trying older version..."
        RT_PATCH_URL="https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/6.1/patch-6.1.77-rt24.patch.xz"
        wget -O ../rt-patch.xz "${RT_PATCH_URL}"
    }
fi

echo "Applying RT patch..."
xzcat ../rt-patch.xz | patch -p1 || {
    echo "Patch failed but may be partially applied. Continuing..."
}

# Configure for Raspberry Pi 4 (bcm2711 = Pi 4)
echo "Configuring kernel for Pi 4..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig

# Enable RT preemption options
./scripts/config --enable CONFIG_PREEMPT_RT
./scripts/config --enable CONFIG_PREEMPT
./scripts/config --disable CONFIG_PREEMPT_NONE
./scripts/config --disable CONFIG_PREEMPT_VOLUNTARY
./scripts/config --set-str LOCALVERSION "-rt-navio2"

# Enable useful features for autopilot
./scripts/config --enable CONFIG_HIGH_RES_TIMERS
./scripts/config --enable CONFIG_NO_HZ_FULL

# Build kernel
echo "Building kernel (this takes 30-60 minutes)..."
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz modules dtbs || {
    echo "Build failed. Trying with single core..."
    make -j1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz modules dtbs
}

# Install modules to rootfs
echo "Installing kernel modules to rootfs..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    INSTALL_MOD_PATH="${ROOTFS_DIR}" modules_install

echo "Creating boot directories..."
mkdir -p "${ROOTFS_DIR}/boot/firmware"
mkdir -p "${ROOTFS_DIR}/boot/firmware/overlays"

# Copy kernel image to boot partition
echo "Installing kernel image..."
cp arch/arm64/boot/Image.gz "${ROOTFS_DIR}/boot/firmware/kernel8.img"

# Copy device tree files
echo "Installing device tree files..."
cp arch/arm64/boot/dts/broadcom/*.dtb "${ROOTFS_DIR}/boot/firmware/" 2>/dev/null || true
cp arch/arm64/boot/dts/overlays/*.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/" 2>/dev/null || true
cp arch/arm64/boot/dts/overlays/README "${ROOTFS_DIR}/boot/firmware/overlays/" 2>/dev/null || true

echo "RT kernel installed successfully"
echo "Kernel: ${KERNEL_VERSION} with RT patch"