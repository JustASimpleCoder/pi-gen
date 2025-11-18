#!/bin/bash -e

# Create systemd services for ArduPilot vehicles

# Create default configuration files
cat > "${ROOTFS_DIR}/etc/default/arducopter" <<'EOF'
# ArduCopter telemetry configuration
# Edit these options as needed

# Telemetry 1: UDP to ground station
TELEM1="-A udp:127.0.0.1:14550"

# Telemetry 2: Serial (uncomment and configure as needed)
#TELEM2="-C /dev/ttyAMA0:115200"

# Additional options
ARDUPILOT_OPTS="$TELEM1 $TELEM2"
EOF

cat > "${ROOTFS_DIR}/etc/default/arduplane" <<'EOF'
# ArduPlane telemetry configuration
TELEM1="-A udp:127.0.0.1:14550"
#TELEM2="-C /dev/ttyAMA0:115200"
ARDUPILOT_OPTS="$TELEM1 $TELEM2"
EOF

cat > "${ROOTFS_DIR}/etc/default/ardurover" <<'EOF'
# ArduRover telemetry configuration
TELEM1="-A udp:127.0.0.1:14550"
#TELEM2="-C /dev/ttyAMA0:115200"
ARDUPILOT_OPTS="$TELEM1 $TELEM2"
EOF

# Create systemd service for ArduCopter
cat > "${ROOTFS_DIR}/etc/systemd/system/arducopter.service" <<'EOF'
[Unit]
Description=ArduPilot (Copter on Navio2)
After=network.target systemd-modules-load.service
Conflicts=arduplane.service ardurover.service

[Service]
Type=simple
EnvironmentFile=/etc/default/arducopter
ExecStart=/usr/bin/arducopter $ARDUPILOT_OPTS
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for ArduPlane
cat > "${ROOTFS_DIR}/etc/systemd/system/arduplane.service" <<'EOF'
[Unit]
Description=ArduPilot (Plane on Navio2)
After=network.target systemd-modules-load.service
Conflicts=arducopter.service ardurover.service

[Service]
Type=simple
EnvironmentFile=/etc/default/arduplane
ExecStart=/usr/bin/arduplane $ARDUPILOT_OPTS
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for ArduRover
cat > "${ROOTFS_DIR}/etc/systemd/system/ardurover.service" <<'EOF'
[Unit]
Description=ArduPilot (Rover on Navio2)
After=network.target systemd-modules-load.service
Conflicts=arducopter.service arduplane.service

[Service]
Type=simple
EnvironmentFile=/etc/default/ardurover
ExecStart=/usr/bin/ardurover $ARDUPILOT_OPTS
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# Enable arducopter by default (user can switch later)
on_chroot <<EOF
systemctl enable arducopter.service
EOF

echo "ArduPilot systemd services created and enabled (default: arducopter)"