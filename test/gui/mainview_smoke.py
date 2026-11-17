"""Standalone home-screen smoke test; run with: uv run --with PySide6 python test/gui/mainview_smoke.py
Uses a mock backend, maps qrc icons to source assets, and writes previews to the system temp directory.
Does not connect to consoles or read user settings.
"""
import os, sys, tempfile
from pathlib import Path
os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["QT_QUICK_BACKEND"] = "software"
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Material"
from PySide6.QtCore import QUrl, Qt, QSize, QRectF, qInstallMessageHandler, QtMsgType
from PySide6.QtGui import QGuiApplication, QImage, QPainter, QFontDatabase, QFont
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtTest import QTest
repo = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
out = Path(tempfile.gettempdir()) / "chiaki-home-preview"
out.mkdir(exist_ok=True)
module = out / "org/streetpea/chiaking"
module.mkdir(parents=True, exist_ok=True)
(module / "qmldir").write_text("module org.streetpea.chiaking\nsingleton Chiaki 1.0 Chiaki.qml\n")
(module / "Chiaki.qml").write_text("""
pragma Singleton
import QtQuick
QtObject {
 property var hosts: []
 property bool autoConnect: false
 property bool discoveryEnabled: true
 property var controllers: []
 property var session: null
 property var window: ({ directStream: false, videoMode: 0, videoPreset: 2, ZoomFactor: 0 })
 property QtObject settings: QtObject {
  property int audioVolume: 100
  property int videoPreset: 2
  property real sZoomFactor: 0
  property bool streamerMode: false
  property bool addSteamShortcutAsk: false
  property bool remotePlayAsk: false
  property string psnAuthToken: "mock"
 }
 property int lastIndex: -1
 function connectToHost(index, name) { lastIndex = index; }
 function wakeUpHost(index) { lastIndex = index; }
 function deleteHost(index) { lastIndex = index; }
 function hideHost(mac, name) {}
 function createSteamShortcut() {}
 function refreshPsnToken() {}
}
""")
(module / "qmldir").write_text((module / "qmldir").read_text() + "singleton ChiakiWindow 1.0 ChiakiWindow.qml\n")
(module / "ChiakiWindow.qml").write_text("""
pragma Singleton
import QtQuick
QtObject {
 enum VideoMode { Normal, Stretch, Zoom }
 enum VideoPreset { Fast, Default, HighQuality, HighQualitySpatial, HighQualityAdvancedSpatial, Custom }
}
""")
# Load actual components; only backend and parent actions are mocked.
for source in [*(repo / "gui/src/qml").rglob("*.qml"), *(repo / "gui/src/qml").rglob("*.js")]:
 destination = out / source.relative_to(repo / "gui/src/qml")
 destination.parent.mkdir(parents=True, exist_ok=True)
 destination.write_text(source.read_text(encoding="utf-8").replace("qrc:/icons/", (repo / "gui/res").as_uri()+"/"),encoding="utf-8")
(out / "MainView.qml").write_text((repo / "gui/src/qml/MainView.qml").read_text(encoding="utf-8").replace("qrc:/icons/", (repo / "gui/res").as_uri() + "/"))
(out / "Preview.qml").write_text("""
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import org.streetpea.chiaking
ApplicationWindow {
 id: root
 width: 1280; height: 800; visible: true
 Material.theme: Material.Dark
 Material.accent: "#00a7ff"
 property bool initialAsk: true
 property string action: ""
 property alias page: home
 function controllerButton(name) { return "image://svg/button-deck#" + name; }
 function showSettingsDialog() { action = "settings"; }
 function showManualHostDialog() { action = "manual"; }
 function showPSNTokenDialog(auto) { action = "signin"; }
 function showSteamShortcutDialog(auto) { action = "steam"; }
 function showConsolePinDialog(index) { action = "pin"; }
 function showConfirmDialog(title, text, callback) { action = "confirm"; }
 function setHosts(value) { Chiaki.hosts = value; }
 function lastIndex() { return Chiaki.lastIndex; }
 function setStreamer(value) { Chiaki.settings.streamerMode = value; }
 MainView { id: home; anchors.fill: parent; focus: true }
}
""")
class SvgProvider(QQuickImageProvider):
 def __init__(self): super().__init__(QQuickImageProvider.Image)
 def requestImage(self, name, size, requested):
  stem, _, element = name.partition("#")
  button = stem.startswith("button-")
  file = repo / "gui/res" / ((stem.replace("button-", "buttons-") if button else stem) + ".svg")
  renderer = QSvgRenderer(str(file))
  dim = requested if requested.width() > 0 else QSize(120, 140)
  size.setWidth(dim.width()); size.setHeight(dim.height())
  img = QImage(dim, QImage.Format_ARGB32_Premultiplied); img.fill(Qt.transparent)
  painter = QPainter(img)
  view = renderer.viewBoxF()
  scale = min(dim.width()/view.width(),dim.height()/view.height())
  def render(part):
   src = renderer.boundsOnElement(part)
   dst = QRectF((dim.width()-view.width()*scale)/2+(src.x()-view.x())*scale,
    (dim.height()-view.height()*scale)/2+(src.y()-view.y())*scale,src.width()*scale,src.height()*scale)
   renderer.render(painter,part,dst)
  if button:
   render("circle"); painter.setCompositionMode(QPainter.CompositionMode_Clear); render(element)
  else:
   render(element); render("console")
   if renderer.elementExists("covers"): render("covers")
  painter.end()
  return img
errors=[]
def log(kind, ctx, message):
 if "Cannot find font directory" in message: return
 if kind in (QtMsgType.QtInfoMsg, QtMsgType.QtDebugMsg): return  # diagnostics, not failures
 errors.append(message)
qInstallMessageHandler(log)
app=QGuiApplication([])
if os.name == "nt":
 QFontDatabase.addApplicationFont("C:/Windows/Fonts/segoeui.ttf")
 QFontDatabase.addApplicationFont("C:/Windows/Fonts/segoeuib.ttf")
 app.setFont(QFont("Segoe UI", 10))
engine=QQmlApplicationEngine()
engine.addImportPath(str(out))
engine.addImageProvider("svg",SvgProvider())
engine.load(QUrl.fromLocalFile(str(out/"Preview.qml")))
assert engine.rootObjects(), errors
window=engine.rootObjects()[0]

def settle(): QTest.qWait(120)
def sethosts(hosts):
 window.setHosts(hosts); settle()
def key(k):
 QTest.keyClick(window,k); settle()
def shot(name,w=1280,h=800):
 window.setWidth(w);window.setHeight(h);settle()
 window.grabWindow().save(str(out/name))
def host(name, **kw):
 return dict(name=name,display=True,registered=True,discovered=True,manual=False,
  ps5=True,state="ready",mac=name,duid="",address="192.0.2.50",app="",**kw)
hidden=host("Hidden");hidden["display"]=False
ready=host("Living room PS5")
rest=host("Bedroom PS5");rest["state"]="standby"
sethosts([hidden,ready,rest])
shot("home-1280.png")
key(Qt.Key_Return)
assert window.lastIndex()==1,window.lastIndex()
# Home D-pad selects Other connections; A opens the secondary console list.
key(Qt.Key_Down);key(Qt.Key_Return)
shot("connections-1280.png")
key(Qt.Key_Down);key(Qt.Key_Return)
assert window.lastIndex()==2,window.lastIndex()
# Reordering discovery results must keep the selected console.
sethosts([rest,hidden,ready]);key(Qt.Key_Return)
assert window.lastIndex()==0,window.lastIndex()
# Wrapping passes the "Add console" card: Up from the first console selects it, Up again the last console.
key(Qt.Key_Up);key(Qt.Key_Up);key(Qt.Key_Return)
assert window.lastIndex()==2,window.lastIndex()
sethosts([ready,hidden,rest]);key(Qt.Key_Return)
assert window.lastIndex()==0,window.lastIndex()
sethosts([rest,hidden,ready]);key(Qt.Key_Return)
assert window.lastIndex()==2,window.lastIndex()
shot("connections-720.png",720,480)
key(Qt.Key_Escape)
shot("home-720.png",720,480)
key(Qt.Key_Yes);shot("manage-menu.png")
key(Qt.Key_Escape);key(Qt.Key_Return)
assert window.lastIndex()==2
# Add / manage panel: first row PSN, second "Add console manually".
key(Qt.Key_Yes);key(Qt.Key_Down);key(Qt.Key_Return)
assert window.property("action") == "manual", window.property("action")
key(Qt.Key_No);shot("console-menu.png");key(Qt.Key_Escape)
sethosts([hidden]); key(Qt.Key_Down);key(Qt.Key_Up)
shot("empty-1280.png")
key(Qt.Key_Return); key(Qt.Key_Escape)
sethosts([]);key(Qt.Key_Down)
shot("empty-720.png",720,480)
assert not errors, "\n".join(errors)
print("PASS: source loaded, hidden indices, wrap navigation (with Add card), discovery reorder, empty/all-hidden lists, side panels.")
print("Previews:",out)