# RaspberryPiStreaming

Live camera stream from a Raspberry Pi 5 + Camera Module, viewable in any
browser on the same WiFi.

**Stream URL:** <http://10.194.110.225:8000/index.html>

## Files

- `image.py` — original local Qt preview (monitor attached).
- `stream_server.py` — headless HTTP server (JPG-polling page + MJPEG endpoint). Same camera settings as `image.py`.
- `camera-stream.service` — systemd unit template.
- `install.sh` — installs deps and registers the auto-start service.
- `uninstall.sh` — removes the service.

## Install on the Pi 5

Raspberry Pi OS Bookworm. Connect the camera ribbon, then:

```bash
cd ~/RaspberryPiStreaming
bash install.sh
```

Installs `python3-picamera2`, enables `camera-stream.service`, prints the LAN
URL. The service starts on boot and restarts on crash.

## View

Open in any browser on the same WiFi:

<http://10.194.110.225:8000/index.html>

## Operate (on the Pi)

```bash
sudo systemctl status camera-stream      # state
sudo journalctl -u camera-stream -f      # logs
sudo systemctl restart camera-stream     # apply changes
bash uninstall.sh                        # disable auto-start
```

## Tweak

Knobs at the top of `stream_server.py`:

- `PORT = 8000`
- `main={"size": (1600, 1200)}` — lower for higher fps.
- `ExposureTime = 50000` (50 ms, 20 fps cap) — lower for more fps if bright.
- `picam2.sensor_modes[3]` — try 0–2 for faster readout.
- `JpegEncoder(q=70)` — smaller frames at minor quality cost.

Restart the service after editing.

## Endpoints

- `/` — JPG-polling page (works in every browser).
- `/snapshot.jpg` — single latest frame.
- `/stream.mjpg` — MJPEG stream (Chrome/Firefox/VLC).

## Troubleshooting

- **Service won't start** → `sudo journalctl -u camera-stream -e`. Usually the camera ribbon. Verify with `rpicam-hello --list-cameras`.
- **Browser blank, `curl` from Mac works** → hard-refresh (Cmd+Shift+R).
- **`ping` from Mac says "No route to host"** → WiFi is isolating clients (common on IllinoisNet/eduroam). Use home WiFi, hotspot, or ethernet.
- **Low fps** → drop resolution, lower `ExposureTime`, or use `JpegEncoder(q=70)`.
