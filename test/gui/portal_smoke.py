"""Portal interaction/animation checks with an isolated backend.
Run: uv run --with PySide6 python test/gui/portal_smoke.py
"""
import runpy
from pathlib import Path
scope=runpy.run_path(str(Path(__file__).with_name("mainview_smoke.py")))
globals().update({k:v for k,v in scope.items() if not k.startswith("__")})
from PySide6.QtCore import QObject
# Exercise the actual home drawer.
window.requestActivate()
sethosts([ready])
key(Qt.Key_Menu)
QTest.qWait(350)
window.grabWindow().save(str(out/"portal-home-quick-menu.png"))
key(Qt.Key_Escape)
# Regression (Steam Deck): after closing, focus must return to the home screen so the
# menu opens again instead of input going to the hidden panel.
drawer=window.findChild(QObject,"quickDrawer")
QTest.qWait(450)
assert not drawer.property("opened")
for attempt in range(2):
    key(Qt.Key_Menu); QTest.qWait(450)
    assert drawer.property("opened"), ("reopen", attempt)
    key(Qt.Key_Escape); QTest.qWait(300)
    assert not drawer.property("opened"), ("close", attempt)
(out/"PortalPreview.qml").write_text("""
import QtQuick
import QtQuick.Controls
import org.streetpea.chiaking
ApplicationWindow {
 id: root
 objectName: "portalPreview"
 width: 1280; height: 800; visible: true; color: "#0b0a15"
 property string action: ""
 property QtObject sampleSession: QtObject {
  property bool connected: true
  property bool muted: true
  property real measuredBitrate: 23.4
  property real averagePacketLoss: 0.003
 }
 function setStreaming(value) { Chiaki.session = value ? sampleSession : null; menu.streaming = value; }
 function micMuted() { return sampleSession.muted; }
 function preset() { return Chiaki.window.videoPreset; }
 PortalGlobe { id: orb; objectName: "orb"; width: 760; height: width; anchors.centerIn: parent }
 PortalQuickMenu {
  id: menu; objectName: "quick"; anchors.right: parent.right; width: 430; height: parent.height
  onCloseRequested: root.action = "close"
  onDisconnectRequested: root.action = "disconnect"
  onStopRequested: sleep => root.action = sleep ? "rest" : "leave-on"
  onDisplaySettingsRequested: root.action = "display"
  onPlaceboSettingsRequested: root.action = "picture"
 }
 PortalPinPad {
  id: pin; objectName: "pin"; anchors.centerIn: parent; width: 460; height: 360; visible: false
  onAccepted: root.action = "pin"
  onCancelled: root.action = "cancel"
 }
 function showPin() { menu.visible = false; orb.visible = false; pin.visible = true; pin.forceActiveFocus(); }
 function showMenu() { menu.visible = true; menu.initialFocusItem.forceActiveFocus(); }
}
""",encoding="utf-8")
engine.load(QUrl.fromLocalFile(str(out/"PortalPreview.qml")))
QTest.qWait(200)
assert any(w.objectName()=="portalPreview" for w in engine.rootObjects()), errors
window=next(w for w in engine.rootObjects() if w.objectName()=="portalPreview")
window.requestActivate();settle()
def key(k):
 QTest.keyClick(window,k);QTest.qWait(120)
orb=window.findChild(QObject,"orb")
p=orb.property("phase");QTest.qWait(160)
assert orb.property("phase")>p
orb.setProperty("running",False);settle()
p=orb.property("phase");QTest.qWait(120)
assert orb.property("phase")==p
orb.setProperty("running",True)
# Entering opens the reveal hole over ~1.15 s and reports completion; leaving resets it.
finished=[]
orb.revealFinished.connect(lambda: finished.append(True))
orb.setProperty("entering",True);QTest.qWait(1400)
assert orb.property("reveal")>=0.999 and orb.property("revealed") and finished, (orb.property("reveal"), finished)
orb.setProperty("entering",False);QTest.qWait(120)
assert orb.property("reveal")==0
window.findChild(QObject,"quick").setProperty("visible",False);settle()
window.setStreaming(True);window.showMenu();settle()
# Input right after opening is ignored (duplicated controller presses); then it works.
key(Qt.Key_Return)
assert window.property("action")=="", window.property("action")
QTest.qWait(400)
window.grabWindow().save(str(out/"portal-stream-menu.png"))
key(Qt.Key_Return)
assert window.property("action")=="close", (window.property("action"), window.activeFocusItem(), errors)
# Tiles are side by side: Right moves from "Return to game" to "Disconnect".
key(Qt.Key_Right);key(Qt.Key_Return);QTest.qWait(400)
# Disconnect with "Ask every time" opens Leave Remote Play; rest mode is focused first.
key(Qt.Key_Return)
assert window.property("action")=="rest", window.property("action")
key(Qt.Key_Escape);QTest.qWait(400)
# Volume slider, then microphone checkbox.
key(Qt.Key_Down);key(Qt.Key_Down);key(Qt.Key_Return)
assert not window.micMuted()
window.showPin();settle()
pin=window.findChild(QObject,"pin")
for digit in [Qt.Key_1,Qt.Key_2,Qt.Key_3,Qt.Key_4,Qt.Key_5]: key(digit)
assert pin.property("text")=="1234" and pin.property("acceptableInput")
key(Qt.Key_No)
assert pin.property("text")=="123" and not pin.property("acceptableInput")
key(Qt.Key_4)
pin.setProperty("selectedKey",11);key(Qt.Key_Return)
assert window.property("action")=="pin"
window.grabWindow().save(str(out/"portal-pin.png"))
pin.setProperty("text","")
pin.setProperty("selectedKey",0);key(Qt.Key_Return)
assert pin.property("text")=="1"
key(Qt.Key_Escape);key(Qt.Key_Escape)
assert window.property("action")=="cancel"
assert not errors, "\n".join(errors)
print("PASS: drawer back; animated/paused globe; enter animation; streaming quick-menu return/disconnect/mic; masked PIN keyboard/controller/validation.")