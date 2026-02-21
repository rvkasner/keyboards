#!/bin/bash

# =============================================================================
#                          KASNER KEYBOARD LAYOUT
# 
# Script to install a pre-compiled kasner.kmap layout for minimal headless 
# Linux distro (eg. Debian)
#
# Note: 
#  - `wget` and `console-setup` should be installed
#  - Run as root
# -----------------------------------------------------------------------------


set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

if ! command -v wget >/dev/null 2>&1; then
    echo "Error: wget is not installed."
    exit 1
fi

echo "Downloading pre-compiled KMAP file..."

mkdir -p /etc/console-setup
wget -O /etc/console-setup/kasner.kmap "https://raw.githubusercontent.com/rvkasner/keyboards/main/os/linux/kmap/kasner.kmap"

echo "Configuring /etc/default/keyboard..."
if grep -q "^KMAP=" /etc/default/keyboard; then
  sed -i 's|^KMAP=.*|KMAP="/etc/console-setup/kasner.kmap"|' /etc/default/keyboard
else
  echo 'KMAP="/etc/console-setup/kasner.kmap"' >> /etc/default/keyboard
fi

echo "Applying configuration and updating initramfs..."
setupcon
update-initramfs -u

echo "Done! The kasner layout has been applied system-wide."