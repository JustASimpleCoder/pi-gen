#!/bin/bash -e

# Install Intel RealSense SDK 2.0 (librealsense2)
# Builds from source for ARM64 architecture

on_chroot <<'EOF'
set -e

echo "Building Intel RealSense SDK 2.0 from source..."

cd /opt

# Clone librealsense
if [ ! -d librealsense ]; then
    git clone https://github.com/IntelRealSense/librealsense.git
fi

cd librealsense

# Checkout latest stable release (or specific version)
# Check for latest release tag
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v2.54.2")
git checkout ${LATEST_TAG}

echo "Building RealSense ${LATEST_TAG}"

# Create build directory
mkdir -p build && cd build

# Configure with CMake
# -DBUILD_EXAMPLES=true to include example programs
# -DBUILD_PYTHON_BINDINGS=true for Python support
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_EXAMPLES=true \
    -DBUILD_PYTHON_BINDINGS=true \
    -DPYTHON_EXECUTABLE=/usr/bin/python3 \
    -DBUILD_WITH_CUDA=false

# Build (this takes a while on Pi 4)
echo "Compiling RealSense (this may take 30-60 minutes)..."
make -j$(nproc)

# Install
make install

# Update library cache
ldconfig

echo "RealSense SDK installed to /usr/local"

# Install Python bindings via pip (alternative method)
pip3 install pyrealsense2 || echo "Note: pyrealsense2 pip install failed, using compiled bindings"

# Set up udev rules for RealSense cameras
if [ -f /opt/librealsense/config/99-realsense-libusb.rules ]; then
    cp /opt/librealsense/config/99-realsense-libusb.rules /etc/udev/rules.d/
    echo "RealSense udev rules installed"
fi

# Test if RealSense is accessible
if command -v rs-enumerate-devices >/dev/null 2>&1; then
    echo "RealSense tools installed successfully"
    echo "Test with: rs-enumerate-devices"
else
    echo "Warning: RealSense tools not found in PATH"
fi

EOF

echo "RealSense installation complete"