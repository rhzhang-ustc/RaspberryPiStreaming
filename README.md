# RaspberryPiStreaming

Headless MJPEG camera stream from a Raspberry Pi 5 + Camera Module, viewable
in any browser from any network via Tailscale.

The Pi runs `stream_server.py` as a systemd service that auto-starts on boot
and auto-restarts on crash. Tailscale gives the Pi a stable `100.x.x.x`
address that bypasses WiFi client isolation (e.g. IllinoisNet, eduroam),
so the same URL works on the institution's WiFi, your home WiFi, cellular,
and anywhere else with internet.

## Files

| File | Purpose |
|---|---|
| `image.py` | Original local Qt preview (used only with a monitor attached). |
| `stream_server.py` | Headless MJPEG-over-HTTP server. Same camera settings as `image.py`. |
| `camera-stream.service` | systemd unit template (paths filled in by `install.sh`). |
| `install.sh` | One-shot installer: apt deps + systemd service + Tailscale. |
| `uninstall.sh` | Disables and removes the camera-stream service. |

## One-time setup on the Pi 5

Assumes Raspberry Pi OS Bookworm (Pi 5 default).

1. **Connect the camera ribbon** (blue side toward the Ethernet port). Verify:
   ```bash
   rpicam-hello --list-cameras
   ```

2. **Copy the project** to the Pi (from your Mac):
   ```bash
   scp -r /Users/ruohanzhang/Documents/RaspberryPiStreaming <user>@<pi-host>:~/
   ```

3. **Run the installer** on the Pi:
   ```bash
   ssh <user>@<pi-host>.local
   cd ~/RaspberryPiStreaming
   bash install.sh
   ```
   It installs `python3-picamera2`, registers the systemd service, installs
   Tailscale, and prints a login URL. Open the URL in any browser and sign
   in (Google / GitHub / email).

   For a fully unattended install, generate a reusable auth key at
   <https://login.tailscale.com/admin/settings/keys> and pass it:
   ```bash
   bash install.sh tskey-auth-XXXXXXX
   ```

4. **Install Tailscale on your viewer device(s)** (Mac, phone, etc.):
   <https://tailscale.com/download> — sign into the **same** account.

5. **In the Tailscale admin console** (<https://login.tailscale.com/admin>),
   one-time tweaks:
   - Machines → click `robotouch` → ⋯ → **Disable key expiry**
     (so the Pi never has to re-auth)
   - DNS settings → enable **MagicDNS**
     (so you can use the hostname instead of the IP)

That's it. Power-cycle the Pi to confirm everything auto-starts.

## Viewing the stream

After install, the script prints the exact URLs. Open in any browser:

- `http://100.x.x.x:8000/` — works from any network (recommended)
- `http://robotouch:8000/` — same thing if MagicDNS is on
- `http://<lan-ip>:8000/` — only works on a friendly WiFi (no client isolation)

Single viewer at a time is recommended; MJPEG re-encodes per client.

## Operating it

| Action | Command (on the Pi) |
|---|---|
| Live stream logs | `sudo journalctl -u camera-stream -f` |
| Service state | `sudo systemctl status camera-stream` |
| Restart streaming | `sudo systemctl restart camera-stream` |
| Tailnet status | `tailscale status` |
| Pi's tailnet IP | `tailscale ip -4` |
| Stop autostart | `bash uninstall.sh` |

You can also `tailscale ssh robotouch` from your Mac (Tailscale SSH is
enabled by `install.sh`), which avoids managing SSH keys.

## Tweaking

- **Camera settings** (gain, exposure, colour gains, sensor mode) live at
  the top of `stream_server.py` and mirror `image.py`. Edit and
  `sudo systemctl restart camera-stream`.
- **Resolution** is set in `stream_server.py` (`main={"size": (1600, 1200)}`).
  Lower it (e.g. `1280, 960`) if WiFi is weak.
- **Port** is `PORT = 8000` at the top of `stream_server.py`.

## Why Tailscale

Institutional WiFi (IllinoisNet, eduroam, most enterprise/guest networks)
enforces **AP client isolation** — peer devices on the same WiFi cannot talk
to each other, even with IPs in the same subnet. Symptom: `ping` from your
laptop to the Pi returns "No route to host" while the Pi can serve to itself
fine. No firewall change on either device fixes this; the AP is dropping
the packets by policy.

Tailscale builds a private WireGuard mesh over your devices' outbound
internet connections, so peer-to-peer traffic flows through the tunnel
regardless of what the underlying WiFi allows. After the one-time login
on each device, the `100.x.x.x` address is stable forever and works on
any network.

## Troubleshooting

- **`stream_server.py` won't start** — check `sudo journalctl -u camera-stream -e`.
  Most common cause is the camera ribbon not seated; confirm with
  `rpicam-hello --list-cameras`.
- **Browser shows nothing but service is "active"** — you're hitting the LAN
  IP from a network that isolates clients. Use the Tailscale URL instead.
- **Tailscale URL doesn't load** — confirm the viewer device is signed in:
  `tailscale status` on the Mac, or open the Tailscale menubar app. Both
  devices must be in the same tailnet and "online".
- **`libcamera-vid: command not found`** — on Bookworm it's renamed
  `rpicam-vid` (in package `rpicam-apps`). Not needed for streaming;
  `stream_server.py` uses Picamera2 directly.
