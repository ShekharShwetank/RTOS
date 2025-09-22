# RTOS
RTOS for Raspberry Pi 5 built during the CATERPILLAR TECH CHALLENGE 2025

# [WINNERS CATERPILLAR TECH CHALLENGE 2025](https://www.linkedin.com/posts/shwetank-shekhar-002b9b203_caterpillartechchallenge-caterpillar100-rtos-activity-7357453575540658177-fU2y?utm_source=share&utm_medium=member_desktop&rcm=ACoAADP3l0IB_pF2cEhbDCVtuh9m-Vzfyl9vxcI)

## Operating System & Kernel Details
1. Operating System: Raspberry Pi OS (64-bit), based on Debian Bookworm.
2. Kernel Version String: 6.15.0-rc7-v8-16k-NTP+
3. Kernel Type: Custom compiled with PREEMPT_RT (Full Real-Time Preemption).
4. Architecture: aarch64 (64-bit).
5. Build Method: Natively compiled on the Raspberry Pi 5.
6. Key Kernel Configurations :
   * Full Real-Time Preemption (CONFIG_PREEMPT_RT=y)
   * Timer Frequency set to 1000 Hz (CONFIG_HZ_1000=y)
   * Full Dynamic Ticks (CONFIG_NO_HZ_FULL=y)
   * Default CPU Frequency Governor set to "performance"
   * Kernel PPS (Pulse Per Second) timing support (CONFIG_NTP_PPS=y)
   * PPS client support for GPIO (CONFIG_PPS_CLIENT_GPIO=y)

## Overview

This repository documents the **complete process of building, deploying, and validating a PREEMPT\_RT real-time kernel** for the **Raspberry Pi 5**.

The **RTOS kernel** enables deterministic scheduling and microsecond-level latency, making it ideal for real-time applications such as robotics, control systems, and embedded AI.

In this project, the RT kernel is used as the foundation for a **real-time monocular depth estimation system**, but this Repository focuses entirely on the **kernel build and deployment** process.

---

## 1. Hardware & Software Requirements

### Hardware

* Raspberry Pi 5 (8GB LPDDR4X-4267 SDRAM)
* 64GB SanDisk microSD card (OS + kernel)
* Optional: 128GB USB 3.2 storage (datasets/logging)
* Official Raspberry Pi Active Cooler (recommended)
* HDMI display (to verify boot and logs)
* GPIO peripherals (optional for testing): LED, buzzer

### Software

* Raspberry Pi OS (64-bit, Debian Bookworm)
* Kernel source: Raspberry Pi Linux `rpi-6.15.y` branch
* PREEMPT\_RT support (integrated into ARM64 kernel ≥6.12)
* Toolchain and dependencies for native compilation

---

## 2. Why PREEMPT\_RT?

The **stock Raspberry Pi OS kernel** is optimized for general-purpose workloads (desktop, server) and cannot guarantee strict timing deadlines.

By compiling and deploying the **PREEMPT\_RT kernel**, we achieve:

* **Full kernel preemption** (CONFIG\_PREEMPT\_RT=y)
* **Deterministic response times (<200µs under stress)**
* **High-resolution scheduler (1000 Hz tick rate)**
* **Reduced jitter** via tickless kernel (CONFIG\_NO\_HZ\_FULL)
* **Stable CPU frequency** (performance governor)

These changes transform the Pi 5 into a **real-time capable system** suitable for robotics, industrial automation, and safety-critical edge AI.

---

## 3. Preparing the Environment

On a fresh Raspberry Pi OS install, run:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install git bc bison flex libssl-dev make -y
sudo apt install libncurses5-dev -y
sudo apt install raspberrypi-kernel-headers -y

mkdir ~/kernel && cd ~
```

---

## 4. Cloning the Kernel Source

Clone the official Raspberry Pi Linux repository:

```bash
git clone --depth 1 --branch rpi-6.15.y https://github.com/raspberrypi/linux
cd linux
```

> ✅ Starting with kernel **6.12**, PREEMPT\_RT is integrated for ARM64 — no external patches needed.

---

## 5. Kernel Configuration

1. Load Raspberry Pi 5 defaults:

   ```bash
   make bcm2712_defconfig
   ```

2. Open menuconfig:

   ```bash
   make menuconfig
   ```

3. Enable the following key options:

   * **General Setup → Preemption Model → Fully Preemptible Kernel (Real-Time)**
   * **Processor type and features → Timer frequency → 1000 Hz**
   * **CPU Frequency Default Governor → performance**
   * **Full dynticks system (CONFIG\_NO\_HZ\_FULL=y)**
   * **NTP/PPS client GPIO support**

4. Disable debugging and power-saving governors to reduce jitter.

---

## 6. Building the Kernel

Compile natively on Raspberry Pi 5:

```bash
make prepare
make CFLAGS='-O3 -march=native' -j6 Image.gz modules dtbs
sudo make -j6 modules_install
```

Recommendation: Use **1.5 × number of CPU cores** for `-j` (Pi 5 has 4 cores → `-j6`).

---

## 7. Deploying the Kernel

### Step 1: Create RT kernel boot directories

```bash
sudo mkdir /boot/firmware/NTP
sudo mkdir /boot/firmware/NTP/overlays-NTP
```

### Step 2: Copy kernel & device trees

```bash
sudo cp arch/arm64/boot/dts/broadcom/*.dtb /boot/firmware/NTP/
sudo cp arch/arm64/boot/dts/overlays/*.dtb* /boot/firmware/NTP/overlays-NTP/
sudo cp arch/arm64/boot/dts/overlays/README /boot/firmware/NTP/overlays-NTP/
sudo cp arch/arm64/boot/Image.gz /boot/firmware/kernel_2712-NTP.img
```

### Step 3: Update boot configuration

Edit `/boot/firmware/config.txt` and add:

```ini
os_prefix=NTP/
overlay_prefix=overlays-NTP/
kernel=/kernel_2712-NTP.img
```

> ⚠️ This ensures the stock kernel remains intact for recovery.

### Step 4: Reboot

```bash
sudo reboot now
```

---

## 8. Verifying the Kernel

After reboot, check:

```bash
uname -a
```

Expected output:

```
Linux raspberrypi 6.15.0-rc7-v8-16k-NTP+ #1 SMP PREEMPT_RT ...
```

---

## 9. Real-Time Performance Testing

Install and run **cyclictest**:

```bash
sudo apt install rt-tests -y
sudo cyclictest -Sp90 -i200 -n -l100000
```

### Results

* **Idle latency:** \~15–20 µs
* **CPU+Memory stress latency:** <200 µs

✅ Confirms deterministic scheduling suitable for real-time tasks.

---

## 10. Troubleshooting

### Boot Failure

* Re-flash SD with Raspberry Pi Imager if unbootable.
* Keep the default kernel untouched for recovery.

### GPIO Errors

* Use `gpiozero` instead of deprecated `RPi.GPIO`.

### GUI Apps with Real-Time Priority

* Run inside Pi desktop session:

  ```bash
  sudo -E chrt -f 75 python3 app.py
  ```

---

## 11. Ready-to-Run Build Script

For convenience, use this **one-step automation script**:

Save as `build_rt_kernel.sh`:

```bash
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
```

Run:

```bash
chmod +x build_rt_kernel.sh
./build_rt_kernel.sh
```

---

## Final Notes

* The PREEMPT\_RT kernel on Raspberry Pi 5 provides **deterministic, microsecond-level scheduling**.
* It is validated under load with **<200µs latency**.
* Applications such as **depth estimation, robotics, and control systems** can now reliably run on the Pi 5 as a **real-time platform**.

---
