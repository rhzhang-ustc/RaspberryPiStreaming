#!/usr/bin/env bash
# One-shot installer for headless Picamera2 MJPEG streaming over Tailscale.
# Run on the Raspberry Pi:
#
#   bash install.sh
#       Interactive Tailscale login: a URL is printed; open it in any
#       browser and sign in with the account you'll also use on your
#       viewer devices.
#
#   bash install.sh tskey-auth-XXXXXXX
#       Non-interactive Tailscale login using a pre-generated auth key
#       from https://login.tailscale.com/admin/settings/keys
#
# Steps performed:
#   1. apt deps (picamera2)
#   2. systemd service for the camera stream (auto-start, auto-restart)
#   3. Tailscale install + login (so the stream is reachable from any network)
set -euo pipefail

AUTHKEY="${1:-}"
PROJECT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SERVICE_NAME="camera-stream.service"
SERVICE_DST="/etc/systemd/system/${SERVICE_NAME}"
RUN_USER="${SUDO_USER:-$USER}"

echo "==> Project dir:      $PROJECT_DIR"
echo "==> Service runs as:  $RUN_USER"
echo

# --- 1. apt deps ------------------------------------------------------------
echo "==> [1/3] Installing system packages (picamera2)..."
sudo apt update
sudo apt install -y python3-picamera2 --no-install-recommends

# --- 2. systemd service -----------------------------------------------------
echo
echo "==> [2/3] Installing systemd unit at $SERVICE_DST ..."
sed -e "s|__USER__|${RUN_USER}|g" \
    -e "s|__PROJECT_DIR__|${PROJECT_DIR}|g" \
    "${PROJECT_DIR}/camera-stream.service" \
    | sudo tee "${SERVICE_DST}" > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"
sleep 2
sudo systemctl --no-pager --full status "${SERVICE_NAME}" | head -n 15 || true

# --- 3. Tailscale -----------------------------------------------------------
echo
echo "==> [3/3] Installing Tailscale..."
if ! command -v tailscale >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "    Tailscale already installed: $(tailscale version | head -n1)"
fi

echo "==> Bringing Tailscale up..."
if [[ -n "$AUTHKEY" ]]; then
    sudo tailscale up --authkey="$AUTHKEY" --hostname="$(hostname)" --ssh
else
    echo
    echo "    A login URL will appear below."
    echo "    Open it in any browser and sign in with the account you will"
    echo "    also use on your laptop/phone Tailscale clients."
    echo
    sudo tailscale up --hostname="$(hostname)" --ssh
fi

sleep 1
TS_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
HOST="$(hostname)"
LAN_IP="$(hostname -I | awk '{print $1}')"

# --- summary ----------------------------------------------------------------
echo
echo "============================================================"
echo "  Install complete."
echo "============================================================"
echo
echo "Stream URLs:"
if [[ -n "$TS_IP" ]]; then
    echo "  Anywhere (Tailscale):   http://${TS_IP}:8000/"
    echo "  Anywhere (MagicDNS):    http://${HOST}:8000/   (if MagicDNS is on)"
fi
echo "  Same WiFi only (LAN):   http://${LAN_IP}:8000/   (blocked on isolated WiFi)"
echo
echo "Next steps:"
echo "  - Install Tailscale on your laptop/phone and sign into the SAME account:"
echo "      https://tailscale.com/download"
echo "  - In the Tailscale admin console (login.tailscale.com/admin):"
echo "      * Disable key expiry for '${HOST}'  (Machines -> ... -> Disable key expiry)"
echo "      * Enable MagicDNS                   (DNS settings -> toggle on)"
echo
echo "Useful commands on the Pi:"
echo "    sudo systemctl status camera-stream     # service state"
echo "    sudo journalctl -u camera-stream -f     # live stream logs"
echo "    sudo systemctl restart camera-stream    # restart streaming"
echo "    tailscale status                        # tailnet peers"
echo "    tailscale ip -4                         # this Pi's tailnet IP"
