#!/usr/bin/env bash
set -euo pipefail

W="$HOME/windows-idx"
D="/var/win11.qcow2"
I="$W/win11-gamer.iso"
F="$W/installed.flag"
L="$W/run.log"
U="https://archive.org/download/tiny-10-23-h2/tiny10%20x64%2023h2.iso"
N="$HOME/.ngrok"
NB="$N/ngrok"
NC="$N/ngrok.yml"
NL="$N/ngrok.log"
NT="38WO5iYPn4Hq5A5SUOjtGptsxfE_7jDB4PmSF78GKcAguUo1H"

exec > >(tee -a "$L") 2>&1
ts() { echo "[$(date '+%H:%M:%S')]"; }

mkdir -p "$W" "$N"
cd "$W"

[ -e /dev/kvm ] || { echo "$(ts) NO KVM"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "$(ts) NO QEMU"; exit 1; }

[ -f "$D" ] || qemu-img create -f qcow2 "$D" 64G

INSTALL=0
if [ ! -f "$F" ]; then
  INSTALL=1
  if [ ! -f "$I" ]; then
    echo "$(ts) Downloading ISO..."
    wget --no-check-certificate -q --show-progress -O "$I" "$U" || { echo "$(ts) ISO download failed"; exit 1; }
  fi
  echo "$(ts) ISO ready"
fi

if [ ! -f "$NB" ]; then
  echo "$(ts) Installing ngrok..."
  curl -sL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar -xz -C "$N"
  chmod +x "$NB"
fi

cat > "$NC" <<EOF
version: "2"
authtoken: $NT
tunnels:
  vnc:
    proto: tcp
    addr: 5900
  rdp:
    proto: tcp
    addr: 3389
EOF

pkill -f ngrok 2>/dev/null || true
sleep 1
"$NB" start --all --config "$NC" --log=stdout > "$NL" 2>&1 &

get_tunnels() {
  for i in $(seq 1 20); do
    R=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null) || { sleep 1; continue; }
    C=$(echo "$R" | grep -c '"public_url"' || true)
    if [ "$C" -ge 2 ]; then
      VNC=$(echo "$R" | grep -oP '"public_url":"tcp://[^"]*' | sed 's/"public_url":"//g' | head -1)
      RDP=$(echo "$R" | grep -oP '"public_url":"tcp://[^"]*' | sed 's/"public_url":"//g' | tail -1)
      echo "$(ts) VNC: ${VNC:-none}"
      echo "$(ts) RDP: ${RDP:-none}"
      return 0
    fi
    sleep 1
  done
  echo "$(ts) Ngrok tunnels timeout"
  return 1
}

get_tunnels

Q_COMMON="-enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
-drive file=$D,if=ide,format=qcow2 \
-netdev user,id=n0,hostfwd=tcp::3389-:3389 \
-device e1000,netdev=n0 -vnc :0 -usb -device usb-tablet -daemonize"

if [ "$INSTALL" -eq 1 ]; then
  echo "$(ts) INSTALL MODE"
  eval qemu-system-x86_64 $Q_COMMON -cdrom "$I" -boot order=d || { echo "$(ts) QEMU failed"; exit 1; }
  echo "$(ts) QEMU started - install Windows via VNC"
  echo "$(ts) Type 'done' when finished"
  while true; do
    read -rp "> " A
    if [ "$A" = "done" ]; then
      touch "$F"
      rm -f "$I"
      pkill -f qemu-system || true
      pkill -f ngrok || true
      echo "$(ts) Saved. Next boot is normal."
      exit 0
    fi
  done
else
  echo "$(ts) BOOT MODE"
  eval qemu-system-x86_64 $Q_COMMON -boot order=c || { echo "$(ts) QEMU failed"; exit 1; }
  echo "$(ts) Windows running"
  wait
fi
