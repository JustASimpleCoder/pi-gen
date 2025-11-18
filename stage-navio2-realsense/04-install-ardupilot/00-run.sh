#!/bin/bash -e

# Build ArduPilot for Navio2 (Copter, Plane, Rover)
# Uses latest stable branches

on_chroot <<'EOF'
set -e

echo "Building ArduPilot for Navio2..."

cd /opt

# Clone ArduPilot
if [ ! -d ardupilot ]; then
    git clone https://github.com/ArduPilot/ardupilot.git
fi

cd ardupilot
git fetch --all

# Find latest stable branches
COPTER_BRANCH=$(git branch -r | awk -F'/' '/origin\/Copter-[0-9]+\./{print $2}' | sort -V | tail -1)
PLANE_BRANCH=$(git branch -r | awk -F'/' '/origin\/Plane-[0-9]+\./{print $2}' | sort -V | tail -1)
ROVER_BRANCH=$(git branch -r | awk -F'/' '/origin\/Rover-[0-9]+\./{print $2}' | sort -V | tail -1)

echo "Using ArduPilot branches:"
echo "  Copter: ${COPTER_BRANCH:-Copter-4.5}"
echo "  Plane:  ${PLANE_BRANCH:-Plane-4.5}"
echo "  Rover:  ${ROVER_BRANCH:-Rover-4.5}"

# Checkout Copter branch (we'll build all three from this checkout)
git checkout ${COPTER_BRANCH:-Copter-4.5}

# Initialize submodules
git submodule update --init --recursive

# Install Python dependencies
if [ -x Tools/environment_install/install-prereqs-ubuntu.sh ]; then
    Tools/environment_install/install-prereqs-ubuntu.sh -y || true
fi

# Configure for Navio2 board
./waf configure --board=navio2

# Build all three vehicle types
echo "Building ArduCopter..."
./waf copter

echo "Building ArduPlane..."
./waf plane

echo "Building ArduRover..."
./waf rover

# Install binaries to /usr/bin
install -m 0755 build/navio2/bin/arducopter /usr/bin/arducopter
install -m 0755 build/navio2/bin/arduplane /usr/bin/arduplane
install -m 0755 build/navio2/bin/ardurover /usr/bin/ardurover

echo "ArduPilot binaries installed:"
echo "  /usr/bin/arducopter"
echo "  /usr/bin/arduplane"
echo "  /usr/bin/ardurover"

# Verify binaries
for binary in arducopter arduplane ardurover; do
    if [ -x /usr/bin/${binary} ]; then
        echo "✓ ${binary} ready"
    else
        echo "✗ ${binary} missing or not executable"
    fi
done

EOF

echo "ArduPilot installation complete"