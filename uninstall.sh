#!/usr/bin/env bash
# Stop and remove the camera streaming service.
set -euo pipefail
SERVICE_NAME="camera-stream.service"
sudo systemctl disable --now "${SERVICE_NAME}" 2>/dev/null || true
sudo rm -f "/etc/systemd/system/${SERVICE_NAME}"
sudo systemctl daemon-reload
echo "camera-stream service removed."
