#!/bin/bash -e

# Install utility scripts for managing Navio2 system

# Create vehicle switcher utility
cat > "${ROOTFS_DIR}/usr/local/sbin/navio-vehicle" <<'EOF'
#!/usr/bin/env bash
# Navio2 Vehicle Switcher
# Usage: sudo navio-vehicle {copter|plane|rover}

set -Eeuo pipefail

usage() {
    echo "Usage: sudo navio-vehicle {copter|plane|rover}"
    echo ""
    echo "Switches between ArduPilot vehicle types on Navio2"
    exit 1
}

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "Error: Must run as root (use sudo)"
    exit 1
fi

# Get vehicle type
VEHICLE="${1:-}"
[[ -n "$VEHICLE" ]] || usage

case "$VEHICLE" in
    copter|plane|rover)
        echo "Switching to ArduPilot ${VEHICLE}..."
        
        # Stop and disable all vehicles
        systemctl stop arducopter.service arduplane.service ardurover.service 2>/dev/null || true
        systemctl disable arducopter.service arduplane.service ardurover.service 2>/dev/null || true
        
        # Enable and start selected vehicle
        systemctl enable ardu${VEHICLE}.service
        systemctl start ardu${VEHICLE}.service
        
        echo ""
        echo "Vehicle switched to: ${VEHICLE}"
        echo "Status:"
        systemctl status ardu${VEHICLE}.service --no-pager --lines=10
        ;;
    *)
        echo "Error: Invalid vehicle type: $VEHICLE"
        usage
        ;;
esac
EOF

chmod +x "${ROOTFS_DIR}/usr/local/sbin/navio-vehicle"

# Create system test utility
cat > "${ROOTFS_DIR}/usr/local/sbin/navio-test" <<'EOF'
#!/usr/bin/env bash
# Navio2 Hardware Test Utility

set -e

echo "===== Navio2 Hardware Test ====="
echo ""

# Check kernel
echo "1. Kernel Check:"
uname -a
if uname -a | grep -q "PREEMPT RT"; then
    echo "   ✓ RT kernel detected"
else
    echo "   ✗ RT kernel NOT detected (non-RT kernel)"
fi
echo ""

# Check SPI devices
echo "2. SPI Devices:"
if ls /dev/spidev* 2>/dev/null; then
    echo "   ✓ SPI devices present"
else
    echo "   ✗ No SPI devices found"
fi
echo ""

# Check I2C
echo "3. I2C Devices:"
if command -v i2cdetect >/dev/null 2>&1; then
    i2cdetect -y 1 || true
else
    echo "   ✗ i2cdetect not found"
fi
echo ""

# Check RCIO
echo "4. RCIO Status:"
if [ -f /sys/kernel/rcio/status/alive ]; then
    RCIO_ALIVE=$(cat /sys/kernel/rcio/status/alive)
    if [ "$RCIO_ALIVE" = "1" ]; then
        echo "   ✓ RCIO alive (value: $RCIO_ALIVE)"
    else
        echo "   ✗ RCIO not alive (value: $RCIO_ALIVE)"
    fi
else
    echo "   ✗ RCIO status not available"
fi
echo ""

# Check RealSense
echo "5. RealSense SDK:"
if command -v rs-enumerate-devices >/dev/null 2>&1; then
    echo "   ✓ RealSense tools installed"
    echo "   Running rs-enumerate-devices:"
    rs-enumerate-devices || echo "   (No cameras connected or permission issue)"
else
    echo "   ✗ RealSense tools not found"
fi
echo ""

# Check ArduPilot binaries
echo "6. ArduPilot Binaries:"
for vehicle in arducopter arduplane ardurover; do
    if [ -x /usr/bin/$vehicle ]; then
        echo "   ✓ $vehicle installed"
    else
        echo "   ✗ $vehicle NOT found"
    fi
done
echo ""

# Check active service
echo "7. Active ArduPilot Service:"
systemctl list-units --type=service --state=running | grep ardu || echo "   No ArduPilot service running"
echo ""

echo "===== Test Complete ====="
echo "Run 'sudo navio-vehicle copter|plane|rover' to start a vehicle"
EOF

chmod +x "${ROOTFS_DIR}/usr/local/sbin/navio-test"

# Create first-boot info script
cat > "${ROOTFS_DIR}/etc/profile.d/navio-motd.sh" <<'EOF'
#!/bin/bash
# Display Navio2 info on first login

if [ -f /etc/navio2-first-boot ]; then
    cat <<'MOTD'

╔═══════════════════════════════════════════════════════════╗
║              Navio2 + RealSense Custom Image              ║
╚═══════════════════════════════════════════════════════════╝

This system includes:
  • PREEMPT_RT kernel for real-time performance
  • Navio2 autopilot HAT drivers (RCIO, sensors)
  • Intel RealSense SDK 2.0
  • ArduPilot (Copter, Plane, Rover)

Quick Commands:
  sudo navio-test              # Test hardware
  sudo navio-vehicle copter    # Switch to copter
  sudo systemctl status arducopter  # Check status

Documentation: /usr/share/doc/navio2/README.md

MOTD
    rm /etc/navio2-first-boot
fi
EOF

# Create first-boot marker
touch "${ROOTFS_DIR}/etc/navio2-first-boot"

echo "Navio2 utilities installed:"
echo "  - /usr/local/sbin/navio-vehicle (switch vehicles)"
echo "  - /usr/local/sbin/navio-test (test hardware)"