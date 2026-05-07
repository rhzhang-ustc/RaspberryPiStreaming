"""
Headless MJPEG-over-HTTP server for Raspberry Pi 5 + Camera Module.

Camera configuration mirrors image.py (sensor mode 3, AnalogueGain=1,
ExposureTime=50000us, ColourGains=(1,1)). The video is encoded as
JPEG frames and served as multipart/x-mixed-replace, so any browser
on the same WiFi network can view it at:

    http://<pi-hostname>.local:8000/

No display, no Qt, no desktop session required.
"""

import io
import logging
import socketserver
from http import server
from threading import Condition

from picamera2 import Picamera2
from picamera2.encoders import JpegEncoder
from picamera2.outputs import FileOutput

PORT = 8000

PAGE = """\
<!DOCTYPE html>
<html>
<head>
<title>Raspberry Pi Camera Stream</title>
<style>
  html, body { margin: 0; padding: 0; background: #000; height: 100%; }
  img { display: block; width: 100vw; height: 100vh; object-fit: contain; }
</style>
</head>
<body>
<img src="stream.mjpg" />
</body>
</html>
"""


class StreamingOutput(io.BufferedIOBase):
    def __init__(self):
        self.frame = None
        self.condition = Condition()

    def write(self, buf):
        with self.condition:
            self.frame = buf
            self.condition.notify_all()


class StreamingHandler(server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            self.send_response(301)
            self.send_header("Location", "/index.html")
            self.end_headers()
        elif self.path == "/index.html":
            content = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        elif self.path == "/stream.mjpg":
            self.send_response(200)
            self.send_header("Age", "0")
            self.send_header("Cache-Control", "no-cache, private")
            self.send_header("Pragma", "no-cache")
            self.send_header(
                "Content-Type", "multipart/x-mixed-replace; boundary=FRAME"
            )
            self.end_headers()
            try:
                while True:
                    with output.condition:
                        output.condition.wait()
                        frame = output.frame
                    self.wfile.write(b"--FRAME\r\n")
                    self.send_header("Content-Type", "image/jpeg")
                    self.send_header("Content-Length", str(len(frame)))
                    self.end_headers()
                    self.wfile.write(frame)
                    self.wfile.write(b"\r\n")
            except (BrokenPipeError, ConnectionResetError):
                logging.info("Client %s disconnected", self.client_address)
        else:
            self.send_error(404)
            self.end_headers()


class StreamingServer(socketserver.ThreadingMixIn, server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")

    global output

    picam2 = Picamera2()
    mode = picam2.sensor_modes[3]
    picam2.configure(
        picam2.create_video_configuration(
            main={"size": (1600, 1200)},
            sensor={"output_size": mode["size"], "bit_depth": mode["bit_depth"]},
        )
    )

    with picam2.controls as ctrl:
        ctrl.AnalogueGain = 1
        ctrl.ExposureTime = 50000
        ctrl.ColourGains = (1, 1)

    output = StreamingOutput()
    picam2.start_recording(JpegEncoder(), FileOutput(output))
    logging.info("Camera started, serving on http://0.0.0.0:%d/", PORT)

    try:
        StreamingServer(("", PORT), StreamingHandler).serve_forever()
    finally:
        picam2.stop_recording()


if __name__ == "__main__":
    main()
