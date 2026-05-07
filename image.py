from PyQt5 import QtCore
from PyQt5.QtWidgets import (QApplication, QHBoxLayout, QLabel, QPushButton,
                             QVBoxLayout, QWidget)

from picamera2 import Picamera2
from picamera2.previews.qt import QGlPicamera2
import time



def post_callback(request):
    label.setText(''.join(f"{k}: {v}\n" for k, v in request.get_metadata().items()))


picam2 = Picamera2()
picam2.post_callback = post_callback
mode = picam2.sensor_modes[3]
picam2.configure(picam2.create_preview_configuration(sensor={'output_size': mode['size'], 'bit_depth': mode['bit_depth']}))

with picam2.controls as ctrl:
  
  ctrl.AnalogueGain = 1
  ctrl.ExposureTime = 50000
  ctrl.ColourGains = 1,  1
  # ctrl.AnalogueGain = 4
  # ctrl.ExposureTime = 210000000
  # ctrl.ColourGains = 1.2, 1.2
  

app = QApplication([])

def on_button_clicked():
    button.setEnabled(False)
    cfg = picam2.create_still_configuration()
    picam2.switch_mode_and_capture_file(cfg, str(time.strftime("%Y%m%d-%H%M%S"))
                                        + ".jpg", signal_function=qpicamera2.signal_done)


def capture_done(job):
    picam2.wait(job)
    button.setEnabled(True)


qpicamera2 = QGlPicamera2(picam2, width=1600, height=1200, keep_ar=False)
button = QPushButton("Click to capture JPEG")
label = QLabel()
window = QWidget()
qpicamera2.done_signal.connect(capture_done)
button.clicked.connect(on_button_clicked)

label.setFixedWidth(400)
label.setAlignment(QtCore.Qt.AlignTop)
layout_h = QHBoxLayout()
layout_v = QVBoxLayout()
layout_v.addWidget(label)
layout_v.addWidget(button)
layout_h.addWidget(qpicamera2, 80)
layout_h.addLayout(layout_v, 20)
window.setWindowTitle("Qt Picamera2 App")
window.resize(1200, 600)
window.setLayout(layout_h)

picam2.start()
window.show()
app.exec()
