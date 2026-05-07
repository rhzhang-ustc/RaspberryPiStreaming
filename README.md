# RaspberryPiStreaming

Headless camera stream from a Raspberry Pi 5 + Camera Module, viewable in any
browser on the same WiFi network.

The Pi runs `stream_server.py` as a systemd service that auto-starts on boot
and auto-restarts on crash. Camera settings (gain, exposure, colour gains,
sensor mode) mirror `image.py`.

## Files

| File | Purpose |
|---|---|
| `image.py` | Original local Qt preview (used only with a monitor attached). |
| `stream_server.py` | Headless HTTP server: JPG-polling page + MJPEG endpoint. |
| `camera-stream.service` | systemd unit template (paths filled in by `install.sh`). |
| `install.sh` | Installs apt deps and registers the systemd service. |
| `uninstall.sh` | Disables and removes the camera-stream service. |

## How the streaming works

`stream_server.py` exposes two endpoints on port 8000:

| URL | What it does | Best for |
|---|---|---|
| `/` (`/index.html`) | HTML page that fetches `/snapshot.jpg` in a JS loop | Universal browser support (Safari included) |
| `/snapshot.jpg` | One JPEG of the latest camera frame | Custom clients, the polling page |
| `/stream.mjpg` | `multipart/x-mixed-replace` MJPEG stream | Lower overhead in Chrome/Firefox; VLC; ffplay |

The default page uses JPG polling because Safari and many embedded WebViews
don't render `multipart/x-mixed-replace` reliably. The MJPEG endpoint stays
available for direct access if you want it.

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

Power-cycle the Pi to confirm the stream auto-starts.

## Viewing the stream

Open in any browser on the same WiFi:

- `http://<pi-hostname>.local:8000/`
- `http://<pi-lan-ip>:8000/`

The page fills the window with the live image. The frame rate self-paces to
the camera + network — typically ~15–20 fps with the default settings.

## Operating it

| Action | Command (on the Pi) |
|---|---|
| Live stream logs | `sudo journalctl -u camera-stream -f` |
| Service state | `sudo systemctl status camera-stream` |
| Restart streaming | `sudo systemctl restart camera-stream` |
| Stop autostart | `bash uninstall.sh` |

After editing `stream_server.py`, run `sudo systemctl restart camera-stream`
to apply changes.

## Tweaking

All knobs live near the top of `stream_server.py`:

- **Port** — `PORT = 8000`.
- **Resolution** — `main={"size": (1600, 1200)}`. Lower it (e.g. `1280, 720`)
  for higher fps over weaker WiFi.
- **Camera settings** — `AnalogueGain`, `ExposureTime`, `ColourGains` mirror
  `image.py`. `ExposureTime = 50000` (50 ms) caps fps at 20; lowering to
  `16000` (16 ms) raises the ceiling to ~60 fps if the scene is bright enough.
- **Sensor mode** — `picam2.sensor_modes[3]`. Try modes 0–2 for faster
  readout at smaller native resolutions.
- **JPEG quality** — pass `JpegEncoder(q=70)` for smaller frames at minor
  visual cost.

## Troubleshooting

- **`stream_server.py` won't start** — check `sudo journalctl -u camera-stream -e`.
  Most common cause is the camera ribbon not seated; confirm with
  `rpicam-hello --list-cameras`.
- **Page loads but image is broken in Safari** — the default page uses JPG
  polling specifically to avoid this. If you still see a broken image, you
  may have an old cached page; hard-refresh with **Cmd+Shift+R**.
- **`curl http://<pi>:8000/index.html` works but the browser shows nothing** —
  cached old version, or you're hitting the MJPEG endpoint directly. Hard-refresh.
- **Connection times out from the laptop, but works from the Pi itself** —
  WiFi is isolating clients (common on institutional networks: IllinoisNet,
  eduroam, guest WiFi). Symptom: `ping <pi-ip>` from your laptop returns
  "No route to host". Use a network without client isolation (home WiFi,
  phone hotspot, ethernet).
- **Low fps / stutter** — drop the resolution and/or `ExposureTime` (see
  Tweaking). WiFi RSSI on the Pi side matters too: `iwconfig wlan0`.
- **`libcamera-vid: command not found`** — on Bookworm it's renamed
  `rpicam-vid` (in package `rpicam-apps`). Not needed for streaming;
  `stream_server.py` uses Picamera2 directly.

## When to consider something else

For genuinely smooth, low-latency, low-bandwidth video (30–60 fps at 1080p
over WiFi), MJPEG/JPG-polling is not the right tool — it sends a full
JPEG every frame. The modern answer is H.264 streamed via
[MediaMTX](https://github.com/bluenviron/mediamtx) and viewed as WebRTC in
the browser. Roughly 5–10× more efficient than MJPEG at the same visual
quality. Out of scope for this repo, but easy to add on top later.
