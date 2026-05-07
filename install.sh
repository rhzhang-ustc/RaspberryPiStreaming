#!/usr/bin/env bash
# One-shot installer for headless WiFi MJPEG streaming.
# Run on the Raspberry Pi:  bash install.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SERVICE_NAME="camera-stream.service"
SERVICE_DST="/etc/systemd/system/${SERVICE_NAME}"
RUN_USER="${SUDO_USER:-$USER}"

echo "==> Project dir: $PROJECT_DIR"
echo "==> Service will run as user: $RUN_USER"

echo "==> Installing system packages (picamera2 only — no GUI deps needed)..."
sudo apt update
sudo apt install -y python3-picamera2 --no-install-recommends

echo "==> Installing systemd unit at $SERVICE_DST ..."
sed -e "s|__USER__|${RUN_USER}|g" \
    -e "s|__PROJECT_DIR__|${PROJECT_DIR}|g" \
    "${PROJECT_DIR}/camera-stream.service" \
    | sudo tee "${SERVICE_DST}" > /dev/null

echo "==> Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"

sleep 2
sudo systemctl --no-pager --full status "${SERVICE_NAME}" || true

HOST="$(hostname)"
IP="$(hostname -I | awk '{print $1}')"
echo
echo "==> Done. Stream URLs (open in any browser on the same WiFi):"
echo "      http://${HOST}.local:8000/"
echo "      http://${IP}:8000/"
echo
echo "Useful commands:"
echo "    sudo systemctl status camera-stream     # state"
echo "    sudo journalctl -u camera-stream -f     # live logs"
echo "    sudo systemctl restart camera-stream    # restart"
