#!/bin/bash -e

# Copy rootfs from previous stage if needed
if [ ! -d "${ROOTFS_DIR}" ]; then
    copy_previous
fi


echo "Rootfs prepared for stage-navio2-realsense"

