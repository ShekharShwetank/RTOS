#!/bin/bash
set -e

echo "[*] Installing dependencies..."
sudo apt update && sudo apt install -y \
    git bc bison flex libssl-dev make libncurses5-dev raspberrypi-kernel-headers

echo "[*] Cloning Raspberry Pi 6.15.y kernel..."
cd ~
[ -d linux ] && sudo rm -rf linux
git clone --depth 1 --branch rpi-6.15.y https://github.com/raspberrypi/linux
cd linux

echo "[*] Configuring kernel..."
make bcm2712_defconfig
yes "" | make menuconfig

echo "[*] Building kernel..."
make prepare
make CFLAGS='-O3 -march=native' -j6 Image.gz modules dtbs
sudo make -j6 modules_install

echo "[*] Setting up boot directories..."
sudo mkdir -p /boot/firmware/NTP/overlays-NTP

echo "[*] Copying kernel and device trees..."
sudo cp arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/NTP/
sudo cp arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/NTP/overlays-NTP/
sudo cp arch/arm64/boot/dts/overlays/README /boot/firmware/NTP/overlays-NTP/
sudo cp arch/arm64/boot/Image.gz /boot/firmware/kernel_2712-NTP.img

echo "[*] Updating /boot/firmware/config.txt..."
sudo tee -a /boot/firmware/config.txt > /dev/null <<EOL
os_prefix=NTP/
overlay_prefix=overlays-NTP/
kernel=/kernel_2712-NTP.img
EOL

echo "[*] Build complete. Rebooting into PREEMPT_RT kernel..."
sudo reboot now
