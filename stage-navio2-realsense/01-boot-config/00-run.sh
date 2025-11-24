#!/bin/bash -e

# Run inside chroot
on_chroot << EOF
set -e

# Paths inside chroot
CFG="/boot/firmware/config.txt"

# Ensure boot firmware directory exists
mkdir -p /boot/firmware

# Create config.txt if missing
if [ ! -f "$CFG" ]; then
    echo "Warning: config.txt not found, creating new one"
    touch "$CFG"
fi

# Backup config
cp -n "$CFG" "${CFG}.backup" 2>/dev/null || true

# Append Navio2 configuration
cat >> "$CFG" << 'EOCFG'

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
EOCFG

# Ensure /etc/modules exists
touch /etc/modules

# Add modules
cat >> /etc/modules << 'EOMOD'
i2c-dev
spidev
EOMOD

echo "Navio2 boot configuration complete"
EOF
