#!/bin/bash -e

# Build PREEMPT_RT kernel for Raspberry Pi 4 (64-bit)
# This stage builds the kernel on the HOST, not in chroot

echo "Building PREEMPT_RT kernel for Raspberry Pi 4..."

# Work directory for kernel build
RT_BUILD_DIR="${WORK_DIR}/rt-kernel-build"
mkdir -p "${RT_BUILD_DIR}"

# Install build dependencies on HOST
apt-get update
apt-get install -y git bc bison flex libssl-dev make libncurses5-dev \
    libncursesw5-dev dwarves kmod cpio rsync fakeroot libelf-dev \
    crossbuild-essential-arm64 xz-utils curl wget

cd "${RT_BUILD_DIR}"

# Clone Raspberry Pi kernel (use 6.6 LTS branch for stability)
if [ ! -d linux ]; then
    echo "Cloning Raspberry Pi kernel (rpi-6.6.y)..."
    git clone --depth=1 --branch rpi-6.6.y https://github.com/raspberrypi/linux.git
fi

cd linux

# Get kernel version for RT patch matching
KERNEL_VERSION=$(make kernelversion)
KERNEL_MAJOR_MINOR=$(echo $KERNEL_VERSION | cut -d. -f1-2)

echo "Kernel version: ${KERNEL_VERSION} (${KERNEL_MAJOR_MINOR})"

# Download appropriate RT patch
RT_BASE_URL="https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt/${KERNEL_MAJOR_MINOR}/"
echo "Fetching RT patch list from: ${RT_BASE_URL}"

# Find latest RT patch for this kernel version
wget -q -O index.html "${RT_BASE_URL}" || { echo "Failed to fetch RT patches"; exit 1; }
RT_PATCH=$(grep -oP 'patch-[0-9.]+-rt[0-9]+\.patch\.(xz|gz)' index.html | sort -V | tail -1)

if [ -z "$RT_PATCH" ]; then
    echo "No RT patch found for kernel ${KERNEL_MAJOR_MINOR}"
    exit 1
fi

echo "Selected RT patch: ${RT_PATCH}"

# Download and apply RT patch
if [ ! -f "../${RT_PATCH}" ]; then
    wget "${RT_BASE_URL}${RT_PATCH}" -O "../${RT_PATCH}"
fi

echo "Applying RT patch..."
case "${RT_PATCH}" in
    *.xz)
        xzcat "../${RT_PATCH}" | patch -p1
        ;;
    *.gz)
        zcat "../${RT_PATCH}" | patch -p1
        ;;
esac

# Configure for Raspberry Pi 4 (bcm2711 = Pi 4)
echo "Configuring kernel for Pi 4..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig

# Enable RT preemption options
./scripts/config --enable CONFIG_PREEMPT_RT
./scripts/config --enable CONFIG_PREEMPT
./scripts/config --disable CONFIG_PREEMPT_NONE
./scripts/config --disable CONFIG_PREEMPT_VOLUNTARY

# Set localversion to identify RT kernel
./scripts/config --set-str LOCALVERSION "-rt-navio2"

# Enable additional useful features for autopilot
./scripts/config --enable CONFIG_HIGH_RES_TIMERS
./scripts/config --enable CONFIG_NO_HZ_FULL

# Build kernel
echo "Building kernel (this takes 30-60 minutes on a fast machine)..."
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz modules dtbs

# Install modules to rootfs
echo "Installing kernel modules to rootfs..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    INSTALL_MOD_PATH="${ROOTFS_DIR}" modules_install

# Copy kernel image to boot partition
echo "Installing kernel image..."
cp arch/arm64/boot/Image.gz "${ROOTFS_DIR}/boot/firmware/kernel8.img"

# Copy device tree files
echo "Installing device tree files..."
cp arch/arm64/boot/dts/broadcom/*.dtb "${ROOTFS_DIR}/boot/firmware/" || true
mkdir -p "${ROOTFS_DIR}/boot/firmware/overlays"
cp arch/arm64/boot/dts/overlays/*.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/" || true
cp arch/arm64/boot/dts/overlays/README "${ROOTFS_DIR}/boot/firmware/overlays/" || true

# Configure boot to use RT kernel
# For Pi 4, kernel8.img is automatically used for 64-bit
echo "RT kernel installed successfully"
echo "Kernel: ${KERNEL_VERSION} with RT patch: ${RT_PATCH}"