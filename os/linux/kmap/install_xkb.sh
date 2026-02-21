#!/bin/bash

# =============================================================================
#                          KASNER KEYBOARD LAYOUT
# 
# Script to install and compile XKB layout for minimal headless Linux 
# distro (eg. Debian)
#
# Note: 
#  - `wget`, `console-setup`, `keyboard-configuration` and `xkb-data` should be installed
#  - Run as root
# -----------------------------------------------------------------------------


set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

echo "Downloading XKB layout..."
wget -O /usr/share/X11/xkb/symbols/kasner "https://raw.githubusercontent.com/rvkasner/keyboards/main/os/linux/xkb/kasner"

echo "Compiling XKB to console KMAP..."
mkdir -p /etc/console-setup
ckbcomp kasner > /etc/console-setup/kasner.kmap

echo "Configuring /etc/default/keyboard..."
if grep -q "^KMAP=" /etc/default/keyboard; then
  sed -i 's|^KMAP=.*|KMAP="/etc/console-setup/kasner.kmap"|' /etc/default/keyboard
else
  echo 'KMAP="/etc/console-setup/kasner.kmap"' >> /etc/default/keyboard
fi

echo "Applying configuration and updating initramfs..."
setupcon
update-initramfs -u

echo "Done! The kasner XKB layout has been compiled and applied system-wide."
