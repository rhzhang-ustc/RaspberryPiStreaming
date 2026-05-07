# RaspberryPiStreaming

Headless MJPEG camera stream from a Raspberry Pi 5 + Camera Module, viewable
in any browser on the same WiFi network.

The Pi runs `stream_server.py` as a systemd service that auto-starts on boot
and auto-restarts on crash.

## Files

| File | Purpose |
|---|---|
| `image.py` | Original local Qt preview (used only with a monitor attached). |
| `stream_server.py` | Headless MJPEG-over-HTTP server. Same camera settings as `image.py`. |
| `camera-stream.service` | systemd unit template (paths filled in by `install.sh`). |
| `install.sh` | Installs apt deps and registers the systemd service. |
| `uninstall.sh` | Disables and removes the camera-stream service. |

## One-time setup on the Pi 5

Assumes Raspberry Pi OS Bookworm (Pi 5 default).

1. **Connect the camera ribbon** (blue side toward the Ethernet port). Verify:
   ```bash
   rpicam-hello --list-cameras
   ```

2. **Run the installer** on the Pi:
   ```bash
   cd ~/RaspberryPiStreaming
   bash install.sh
   ```
   It installs `python3-picamera2` and registers the systemd service. The
   script prints the LAN URL when finished.

That's it. Power-cycle the Pi to confirm the stream auto-starts.

## Viewing the stream

Open in any browser on the same WiFi:

- `http://<pi-hostname>.local:8000/`
- `http://<pi-lan-ip>:8000/`

Single viewer at a time is recommended; MJPEG re-encodes per client.

## Operating it

| Action | Command (on the Pi) |
|---|---|
| Live stream logs | `sudo journalctl -u camera-stream -f` |
| Service state | `sudo systemctl status camera-stream` |
| Restart streaming | `sudo systemctl restart camera-stream` |
| Stop autostart | `bash uninstall.sh` |

## Tweaking

- **Camera settings** (gain, exposure, colour gains, sensor mode) live at
  the top of `stream_server.py` and mirror `image.py`. Edit and
  `sudo systemctl restart camera-stream`.
- **Resolution** is set in `stream_server.py` (`main={"size": (1600, 1200)}`).
  Lower it (e.g. `1280, 960`) if WiFi is weak.
- **Port** is `PORT = 8000` at the top of `stream_server.py`.

## Troubleshooting

- **`stream_server.py` won't start** — check `sudo journalctl -u camera-stream -e`.
  Most common cause is the camera ribbon not seated; confirm with
  `rpicam-hello --list-cameras`.
- **Browser shows nothing but service is "active"** — your WiFi may be
  isolating clients (common on institutional networks like IllinoisNet,
  eduroam, guest WiFi). Symptom: `ping <pi-ip>` from your laptop returns
  "No route to host" while the Pi can serve to itself fine. Use a network
  without client isolation (home WiFi, phone hotspot, ethernet).
- **`libcamera-vid: command not found`** — on Bookworm it's renamed
  `rpicam-vid` (in package `rpicam-apps`). Not needed for streaming;
  `stream_server.py` uses Picamera2 directly.
