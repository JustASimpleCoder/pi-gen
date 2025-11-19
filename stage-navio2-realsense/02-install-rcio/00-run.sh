#!/bin/bash -e

# Install RCIO DKMS module for Navio2
# This handles PWM output, RC input, and LED control

#on_chroot <<EOF
set -e

# Clone RCIO DKMS repository
cd /usr/src
if [ ! -d rcio-dkms ]; then
    git clone https://github.com/emlid/rcio-dkms.git
fi

cd rcio-dkms

# Get version from dkms.conf
VER=\$(awk -F'[" ]' '/PACKAGE_VERSION/{print \$3}' dkms.conf)

# Build and install via DKMS
dkms add .
dkms build rcio/\${VER}
dkms install rcio/\${VER}

echo "RCIO DKMS module installed (version \${VER})"
echo "Module will be loaded automatically on boot"

# Create modprobe configuration to auto-load modules
cat > /etc/modprobe.d/rcio.conf <<'MODPROBE'
# Auto-load RCIO modules for Navio2
options rcio_core
MODPROBE

# Add to modules to load at boot
echo "rcio_core" >> /etc/modules-load.d/rcio.conf
echo "rcio_spi" >> /etc/modules-load.d/rcio.conf

EOF

echo "RCIO installation complete"