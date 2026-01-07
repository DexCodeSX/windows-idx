#!/usr/bin/env bash
set -e

### CONFIG ###
ISO_URL="https://onedrive-cf.cloudmini.net/api/raw?path=/Public/Vultr/M%E1%BB%9Bi%201909/Update%200907/Win10_ltsc_x64FRE_en-us.iso"
ISO_FILE="win11-gamer.iso"

DISK_FILE="win11.qcow2"
DISK_SIZE="64G"

RAM="8G"
CORES="4"
THREADS="2"

VNC_DISPLAY=":0"   # 5900
RDP_PORT="3389"

### CHECK KVM ###
[ -e /dev/kvm ] || { echo "❌ no /dev/kvm"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ no qemu"; exit 1; }

### ISO ###
[ -f "${ISO_FILE}" ] || wget -O "${ISO_FILE}" "${ISO_URL}"

### DISK ###
[ -f "${DISK_FILE}" ] || qemu-img create -f qcow2 "${DISK_FILE}" "${DISK_SIZE}"

echo "🚀 Windows 11 KVM BIOS + SCSI (LSI)"
echo "🖥️  VNC : localhost:5900"
echo "🖧  RDP : localhost:3389"

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 8 \
  -m 16G \
  -machine q35 \
  -drive file=/win11.qcow2,if=virtio,format=qcow2 \
  -vnc :0 \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -device virtio-net,netdev=net0 \
  -usb -device usb-tablet
