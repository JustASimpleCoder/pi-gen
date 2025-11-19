#!/bin/bash -e

# Configure boot overlays for Navio2
# This runs during image build, not on first boot

CFG="${ROOTFS_DIR}/boot/firmware/config.txt"

# Backup config.txt
cp -n "$CFG" "${CFG}.backup" || true

# Add Navio2 required overlays
cat >> "$CFG" <<'EOF'

# Navio2 Configuration
dtoverlay=spi0-4cs
dtoverlay=spi1-1cs
dtparam=spi=on
dtparam=i2c_arm=on
dtparam=i2c1=on
dtparam=i2c1_baudrate=1000000
dtoverlay=rcio
dtoverlay=navio-rgb

# Enable UART for GPS/Telemetry
enable_uart=1
EOF

# Enable kernel modules at boot
cat >> "${ROOTFS_DIR}/etc/modules" <<'EOF'
i2c-dev
spidev
EOF

echo "Navio2 boot configuration complete"
