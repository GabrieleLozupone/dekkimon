"""GPU preview of the Portal-style UI with a mock backend (no console, no user settings).

Run:  uv run --with PySide6 --with pillow python test/gui/portal_preview.py [scene ...]
Scenes: globe, home, connect, quick, quick-stream, pin, settings  (default: all)
Writes PNG stills plus a connect-transition GIF/MP4 frames to %TEMP%/chiaki-portal-preview.

Unlike the smoke tests this uses the platform GPU backend, because the globe is a
ShaderEffect (the software renderer cannot run shaders).
"""
import os, sys, shutil, subprocess, tempfile
from pathlib import Path

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Material")
# Render at the Steam Deck's native 1280x800 regardless of the desktop scale.
os.environ["QT_ENABLE_HIGHDPI_SCALING"] = "0"
import PySide6
from PySide6.QtCore import QUrl, QObject, Qt, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest

repo = Path(__file__).resolve().parents[2]
out = Path(tempfile.gettempdir()) / "chiaki-portal-preview"
qml_out = out / "qml"
shutil.rmtree(qml_out, ignore_errors=True)
qml_out.mkdir(parents=True)
icons_uri = (repo / "gui/res").as_uri() + "/"
portal_uri = qml_out.as_uri() + "/"

# Bake the shader exactly as qt_add_shaders would.
qsb = Path(PySide6.__file__).parent / ("qsb.exe" if os.name == "nt" else "qsb")
subprocess.run([str(qsb), "--glsl", "100 es,120,150", "--hlsl", "50", "--msl", "12", "-o",
                str(qml_out / "portalglobe.frag.qsb"), str(repo / "gui/src/qml/shaders/portalglobe.frag")], check=True)

for source in [*(repo / "gui/src/qml").rglob("*.qml"), *(repo / "gui/src/qml").rglob("*.js")]:
    dest = qml_out / source.relative_to(repo / "gui/src/qml")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(source.read_text(encoding="utf-8")
                    .replace("qrc:/icons/", icons_uri).replace("qrc:/portal/", portal_uri), encoding="utf-8")

module = qml_out / "org/streetpea/chiaking"
module.mkdir(parents=True, exist_ok=True)
(module / "qmldir").write_text("module org.streetpea.chiaking\nsingleton Chiaki 1.0 Chiaki.qml\nsingleton ChiakiWindow 1.0 ChiakiWindow.qml\n")
(module / "ChiakiWindow.qml").write_text("""
pragma Singleton
import QtQuick
QtObject {
 enum VideoMode { Normal, Stretch, Zoom }
 enum VideoPreset { Fast, Default, HighQuality, HighQualitySpatial, HighQualityAdvancedSpatial, Custom }
}
""")
import re as _re
_model = (repo / "gui/src/qml/PortalSettingsModel.qml").read_text(encoding="utf-8")
_app = (repo / "gui/src/qml/PortalAppSettingsModel.qml").read_text(encoding="utf-8")
_names = sorted((set(_re.findall(r'"((?:placebo|display)\w+)"', _model)) | set(_re.findall(r'Chiaki\.settings\.((?:placebo|display)\w+)', _model))
                 | set(_re.findall(r'(?:toggle|choice|slider)\("(\w+)"', _app)) | set(_re.findall(r'Chiaki\.settings\.(\w+)(?![\w(])', _app))
                 | {f"{k}{p}{c}" for k in ("resolution", "fps", "bitrate", "codec") for p in ("Local", "Remote") for c in ("PS4", "PS5")})
                - {"audioVolume", "videoPreset", "streamerMode", "showStreamStats", "audioVideoDisabled", "psnAuthToken"})
_defaults = {"placeboUpscaler": 9, "placeboDownscaler": 2, "placeboGamutMappingFunction": 1, "placeboToneMappingFunction": 1,
             "placeboDebandEnabled": True, "placeboDebandPreset": 1, "placeboSigmoidEnabled": True, "placeboSigmoidPreset": 1,
             "placeboColorAdjustmentEnabled": True, "placeboColorAdjustmentPreset": 1, "placeboPeakDetectionEnabled": True,
             "placeboPeakDetectionPreset": 2, "placeboColorMappingEnabled": True, "placeboColorMappingPreset": 2,
             "displayTargetPeak": 1000, "placeboDebandThreshold": 3.0, "placeboDebandRadius": 16.0, "placeboDebandGrain": 4.0,
             "placeboDebandIterations": 1, "placeboToneMappingKneeDefault": 0.4, "placeboToneMappingContrastRecovery": 0.3,
             "placeboToneMappingContrastSmoothness": 3.5, "placeboGamutMappingLut3dSizeI": 48, "placeboGamutMappingLut3dSizeC": 32,
             "placeboGamutMappingLut3dSizeH": 256, "placeboToneMappingToneLutSize": 256, "placeboColorAdjustmentContrast": 1.0,
             "placeboColorAdjustmentSaturation": 1.0, "placeboColorAdjustmentGamma": 1.0,
             "disconnectAction": 2, "windowType": 3, "streamMenuEnabled": True, "streamMenuShortcut1": 9, "streamMenuShortcut2": 10,
             "streamMenuShortcut3": 11, "streamMenuShortcut4": 12, "directFrameMapping": True, "hideCursor": True,
             "availableDecoders": ["auto", "vulkan", "vaapi"], "decoder": "", "availableAudioOutDevices": ["Steam Deck speakers"],
             "availableAudioInDevices": ["Steam Deck microphone"], "audioOutDevice": "", "audioInDevice": "", "audioBufferSize": 9600,
             "noiseSuppressLevel": 6, "echoSuppressLevel": 30, "wifiDroppedNotif": 3, "packetLossReportedMax": 5,
             "registeredHosts": [{"name": "Living room PS5", "mac": "00:00:00:00:00:01", "ps5": True}], "autoConnectMac": "",
             "rumbleHapticsIntensity": 3, "hapticOverride": 1.0, "dpadTouchIncrement": 30, "logSanitize": True,
             "psnRefreshToken": "mock", "psnAuthTokenExpiry": "mock", "psnAccountId": "mock", "psnOnlineId": "SamplePlayer",
             "portGuessCount": 75, "portGuessSocketCount": 250, "logDirectory": "/home/deck/.local/share/chiaki/log",
             "resolutionLocalPS5": 4, "resolutionRemotePS5": 3, "resolutionLocalPS4": 3, "resolutionRemotePS4": 3,
             "controllerMapping": [{"buttonName": "Cross", "buttonValue": 1, "keyName": "Return"}, {"buttonName": "Circle", "buttonValue": 2, "keyName": "Escape"}, {"buttonName": "Square", "buttonValue": 3, "keyName": "Backspace"}],
             "fpsLocalPS5": 60, "fpsRemotePS5": 60, "fpsLocalPS4": 60, "fpsRemotePS4": 60, "codecLocalPS5": 2, "codecRemotePS5": 1}
def _qml(v):
    import json
    return "true" if v is True else "false" if v is False else json.dumps(v)
_mock_settings = chr(10).join(f"  property var {n}: {_qml(_defaults.get(n, 0))}" for n in _names)
(module / "Chiaki.qml").write_text("""
pragma Singleton
import QtQuick
QtObject {
 property var hosts: [{ display: true, name: "Living room PS5", ps5: true, registered: true, discovered: true,
                        state: "ready", mac: "00:00:00:00:00:01", address: "192.0.2.10", app: "Lantern Valley" },
                      { display: true, name: "Bedroom PS5", ps5: true, registered: true, discovered: true,
                        state: "standby", mac: "00:00:00:00:00:03", address: "192.0.2.11", app: "" }]
 property bool autoConnect: false
 property bool discoveryEnabled: true
 property var controllers: [{ playStation: false }]
 property var session: null
 property QtObject wifi: QtObject {
  property bool active: false
  property string kind: "wifi"
  property int signalDbm: -71
  property real linkMbps: 288
  property int frequencyMhz: 5180
  property int channel: 36
  property int widthMhz: 80
  property int quality: 4
  property int recommendedBitrate: 30
  property bool roamingScans: false
  property bool scanCheckKnown: true
 }
 function stopSession(sleep) { console.log("preview: stopSession " + sleep); }
 property var window: ({ directStream: false, videoMode: 0, videoPreset: 2, ZoomFactor: 0,
                         runtimeRendererBackend: 0, loadingTransitionComplete: false })
 property QtObject settings: QtObject {
  property int audioVolume: 100
  property int videoPreset: 2
  property real sZoomFactor: 0
  property bool streamerMode: false
  property bool addSteamShortcutAsk: false
  property bool remotePlayAsk: false
  property string psnAuthToken: "mock"
  property bool showStreamStats: false
  property int audioVideoDisabled: 0
""" + _mock_settings + """
  function exportPlaceboSettings() {}
  function restartApplication() { return false; }
  function deleteRegisteredHost(i) {}
  function clearKeyMapping() {}
  function exportSettings() {}
  function importSettings() {}
  function importPlaceboSettings() {}
  property var profiles: ["Living room", "Travel"]
  property string currentProfile: ""
  function deleteProfile(p) {}
  function changeControllerKey(v, k) { return "K"; }
  function chooseSteamBasePath() {}
 }
 function openPlaceboOptionsLink() { return "https://example.invalid/docs"; }
 property var hiddenHosts: [{ name: "Bedroom PS4", mac: "00:00:00:00:00:02" }]
 function unhideHost(mac) {}
 function fetchPsnOnlineId() {}
 signal psnPhoneLoginConnected(string peer)
 signal psnPhoneLoginRedirect(string url, string peer)
 signal psnPhoneLoginExpired()
 function startPsnPhoneLogin() { return "http://192.0.2.20:47990/3f9c1e0a6b7d4c2e9a1f5b8d0c3e7a21"; }
 function stopPsnPhoneLogin() {}
 function psnPhoneLoginError() { return ""; }
 function initPsnAuth(url, cb) { cb("ok", true, true); }
 function connectToHost(index, name) {}
 function wakeUpHost(index) {}
 function deleteHost(index) {}
 function hideHost(mac, name) {}
 function refreshPsnToken() {}
 // Legacy dialogs (manual host, registration, Steam shortcut, controller mapping)
 function addManualHost(index, address) {}
 function registerHost(host, psnId, pin, cpin, broadcast, target, cb) {}
 function createSteamShortcut(name, options, cb, steamDir) { cb("Found Steam user 1000", true, false); cb("Wrote artwork for " + name, true, false); cb("Shortcut created", true, true); }
 property string currentControllerType: "DualSense"
 property var currentControllerMapping: [{ buttonName: "Cross", buttonValue: 1, physicalButton: ["A"] }, { buttonName: "Circle", buttonValue: 2, physicalButton: ["B", "Back paddle"] }, { buttonName: "Square", buttonValue: 3, physicalButton: ["X"] }, { buttonName: "Triangle", buttonValue: 4, physicalButton: ["Y"] }, { buttonName: "PS", buttonValue: 16, physicalButton: [] }]
 property bool enableAnalogStickMapping: false
 property bool controllerMappingInProgress: false
 property bool controllerMappingAltered: true
 signal controllerMappingButtonQuit()
 signal controllerMappingQuit()
 signal controllerMappingButtonSelected(var pressedButton, int chiakiButtonValue, string chiakiButtonName)
 signal controllerMappingSteamControllerSelected()
 function beginControllerMapping(reset) {}
 function controllerMappingSelectButton() {}
 function controllerMappingApply() {}
 function updateButton(chiakiButton, buttonName, value) {}
}
""")

(qml_out / "Preview.qml").write_text("""
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import org.streetpea.chiaking
ApplicationWindow {
 id: root
 objectName: "preview"
 width: 1280; height: 800; visible: true
 color: "black"
 Material.theme: Material.Dark
 property bool initialAsk: true
 property string scene: ""
 function controllerButton(name) { return "image://svg/button-deck#" + name; }
 function showSettingsDialog() {}
 function showManualHostDialog() {}
 function showPSNTokenDialog(auto) {}
 function showSteamShortcutDialog(auto) {}
 function showConsolePinDialog(index) {}
 function showConfirmDialog(title, text, callback) {}
 property QtObject sampleSession: QtObject {
  property bool connected: true
  property bool muted: false
  property real measuredBitrate: 38.6
  property real averagePacketLoss: 0.002
 }
 // Link presets: "good" = 80 MHz on channel 36 (the user's room), "weak" = 40 MHz, far, scans on.
 function setWifi(preset) {
  const w = Chiaki.wifi;
  if (preset === "weak") {
   w.signalDbm = -77; w.linkMbps = 69; w.frequencyMhz = 5500; w.channel = 100; w.widthMhz = 40;
   w.recommendedBitrate = 12; w.quality = 2; w.roamingScans = true;
   Chiaki.settings.bitrateLocalPS5 = 25000;
  } else {
   w.signalDbm = -71; w.linkMbps = 288; w.frequencyMhz = 5180; w.channel = 36; w.widthMhz = 80;
   w.recommendedBitrate = 30; w.quality = 4; w.roamingScans = false;
   Chiaki.settings.bitrateLocalPS5 = 20000;
  }
 }

 // Stand-in for the console UI that the reveal uncovers (in the app this is live video).
 Rectangle {
  id: fakeStream
  anchors.fill: parent
  visible: ["sequence", "quick-stream", "color-hdr", "picture", "leave", "picture-page", "conn-stream"].indexOf(root.scene) >= 0
  gradient: Gradient {
   GradientStop { position: 0; color: "#1c3f73" }
   GradientStop { position: 0.55; color: "#0f1f3d" }
   GradientStop { position: 1; color: "#070b16" }
  }
  Row {
   x: 64; y: 120; spacing: 18
   Repeater {
    model: 6
    Rectangle {
     width: index === 0 ? 170 : 110; height: width; radius: 18
     color: ["#e7a33e", "#3b7dd8", "#c0392b", "#16a085", "#8e44ad", "#2c3e50"][index]
     border.width: index === 0 ? 4 : 0; border.color: "white"
    }
   }
  }
  Text { x: 64; y: 330; text: "Game title"; color: "white"; font.pixelSize: 44; font.weight: Font.Light }
  Rectangle { x: 64; y: 400; width: 210; height: 56; radius: 28; color: "white"
   Text { anchors.centerIn: parent; text: "Play"; font.pixelSize: 22; color: "#111" } }
  // PREVIEW_STREAM_IMAGE: an original picture to show as the stream (public screenshots).
  Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; source: "STREAM_IMAGE_URI"; visible: source != "" }
 }
 Loader { id: loader; anchors.fill: parent }
 Component { id: globeOnly; PortalGlobe { objectName: "globe" } }
 Component { id: homeScene; MainView { objectName: "home" } }
 Component { id: sequenceScene
  Item {
   MainView { objectName: "home"; anchors.fill: parent }
   PortalConnectOverlay { objectName: "connect"; anchors.fill: parent; opacity: 0; consoleName: "Living room PS5" }
  }
 }
 Component { id: streamMenuScene
  Item {
   Rectangle { anchors.fill: parent; color: "#55000000" }
   PortalQuickMenu {
    objectName: "streamMenu"
    anchors.right: parent.right
    width: Math.min(430, parent.width); height: parent.height
    streaming: root.scene !== "home-menu"
    Component.onCompleted: initialFocusItem.forceActiveFocus()
   }
  }
 }
 Component { id: colorHdrScene
  Item {
   Rectangle { anchors.fill: parent; color: "#101116"; opacity: 0.8 }
   DisplaySettingsDialog { objectName: "settingsDialog"; anchors.fill: parent }
  }
 }
 Component { id: pictureScene
  Item {
   Rectangle { anchors.fill: parent; color: "#101116"; opacity: 0.8 }
   PlaceboSettingsDialog { objectName: "settingsDialog"; anchors.fill: parent }
  }
 }
 Component { id: settingsScene
  Item {
   SettingsDialog { objectName: "settingsDialog"; anchors.fill: parent }
  }
 }
 RemindDialog { id: remindDialog; objectName: "remindDialog" }
 ConfirmDialog { id: confirmDialog; objectName: "confirmDialog" }
 Component { id: psnPhoneScene
  PSNPhoneSignIn { objectName: "psnPhone"; anchors.fill: parent }
 }
 Component { id: pinScene
  ConsolePinDialog { objectName: "pinDialog"; anchors.fill: parent }
 }
 Component { id: manualHostScene; ManualHostDialog { objectName: "legacy"; anchors.fill: parent } }
 Component { id: registScene; RegistDialog { objectName: "legacy"; anchors.fill: parent; host: "192.0.2.10"; ps5: true } }
 Component { id: profileScene; ProfileDialog { objectName: "legacy"; anchors.fill: parent } }
 Component { id: steamShortcutScene; SteamShortcutDialog { objectName: "legacy"; anchors.fill: parent } }
 Component { id: controllerMappingScene; ControllerMappingDialog { objectName: "legacy"; anchors.fill: parent } }
 readonly property var legacyScenes: ({ "manual-host": manualHostScene, "regist": registScene, "profile": profileScene,
                                       "steam-shortcut": steamShortcutScene, "controller-mapping": controllerMappingScene })
 function openRemind() {
  remindDialog.title = qsTr("Remote Play via PSN");
  remindDialog.text = qsTr("Sign in to PlayStation Network to register consoles automatically and to play away from home without port forwarding.") + "

" + qsTr("You can do this later in Settings › Remote access.");
  remindDialog.remotePlay = true; remindDialog.callback = () => {}; remindDialog.open();
 }
 function openConfirm() {
  confirmDialog.title = qsTr("Quit"); confirmDialog.text = qsTr("Are you sure you want to quit?");
  confirmDialog.callback = () => {}; confirmDialog.open();
 }
 function closeDialog() { console.log("preview: closeDialog"); }
 function openKeyRows(view) { view.openPage(view.model.page("Edit key mapping", "", () => view.model.keyRows())); }
 function show(name) {
  scene = name;
  loader.sourceComponent = null;   // always start a scene from a fresh instance
  Chiaki.session = ["quick-stream", "leave", "picture-page", "conn-stream"].indexOf(name) >= 0 ? sampleSession : null;
  if (name === "pin") Chiaki.setConsolePin = (i, p) => {};
  if (legacyScenes[name]) { loader.sourceComponent = legacyScenes[name]; return; }
  loader.sourceComponent = name === "psn-phone" ? psnPhoneScene : name === "pin" ? pinScene : name === "settings" ? settingsScene : name === "color-hdr" ? colorHdrScene : name === "picture" ? pictureScene
     : name === "globe" ? globeOnly : name === "sequence" ? sequenceScene
     : ["quick-stream", "leave", "picture-page", "conn-stream", "home-menu"].indexOf(name) >= 0 ? streamMenuScene : homeScene;
 }
}
""".replace("STREAM_IMAGE_URI", Path(os.environ["PREVIEW_STREAM_IMAGE"]).resolve().as_uri() if os.environ.get("PREVIEW_STREAM_IMAGE") else ""), encoding="utf-8")

errors = []
def handler(mode, context, message):
    if "Warning" in str(mode) or "Critical" in str(mode) or "Fatal" in str(mode):
        errors.append(message)
    print(message)
qInstallMessageHandler(handler)

from PySide6.QtSvg import QSvgRenderer
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtGui import QImage, QPainter
from PySide6.QtCore import QRectF

class Qr(QQuickImageProvider):
    """Mirror of QrImageProvider: image://qr/<percent-encoded text>."""
    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Image)
    def requestImage(self, ident, size, requested):
        import segno, urllib.parse
        q = segno.make(urllib.parse.unquote(ident), error="m")
        m = q.matrix
        n = len(m) + 8
        scale = max(1, (requested.width() if requested.width() > 0 else n * 8) // n)
        img = QImage(n * scale, n * scale, QImage.Format_RGB32); img.fill(0xffffffff)
        p = QPainter(img)
        for y, row in enumerate(m):
            for x, v in enumerate(row):
                if v: p.fillRect((x + 4) * scale, (y + 4) * scale, scale, scale, 0xff101116)
        p.end()
        return img

class Svg(QQuickImageProvider):
    """Mirror of qmlsvgprovider: image://svg/<file>#<element>."""
    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Image)
    def requestImage(self, ident, size, requested):
        name, _, element = ident.partition("#")
        renderer = QSvgRenderer(str(repo / "gui/res" / (name.replace("button-", "buttons-") + ".svg")))
        w = requested.width() if requested.width() > 0 else 48
        h = requested.height() if requested.height() > 0 else 48
        img = QImage(w, h, QImage.Format_ARGB32_Premultiplied)
        img.fill(0)
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing)
        if element and name.startswith("button-"):
            # Same as QmlSvgProvider::drawButtonImage: filled disc, glyph punched out.
            box = renderer.viewBoxF()
            def place(el):
                b = renderer.boundsOnElement(el).translated(-box.left(), -box.top())
                return QRectF(w * b.left() / box.width(), h * b.top() / box.height(),
                              w * b.width() / box.width(), h * b.height() / box.height())
            renderer.render(p, "circle", place("circle"))
            p.setCompositionMode(QPainter.CompositionMode_Clear)
            renderer.render(p, element, place(element))
        elif element:
            # Same as QmlSvgProvider for console art: the light element, then the console body,
            # both placed at their own position in the view box (aspect kept).
            box = renderer.viewBoxF()
            scale = min(w / box.width(), h / box.height())
            def place_fit(el):
                b = renderer.boundsOnElement(el)
                return QRectF((w - box.width() * scale) / 2 + (b.x() - box.x()) * scale,
                              (h - box.height() * scale) / 2 + (b.y() - box.y()) * scale,
                              b.width() * scale, b.height() * scale)
            renderer.render(p, element, place_fit(element))
            if renderer.elementExists("console"):
                renderer.render(p, "console", place_fit("console"))
            if renderer.elementExists("covers"):
                renderer.render(p, "covers", place_fit("covers"))
        else:
            renderer.render(p)
        p.end()
        return img

app = QGuiApplication(sys.argv[:1])
# Same version text as the app: "<dekkimon.version> (chiaki-ng <CHIAKI_VERSION>)".
import re as _re
_cm = (repo / "CMakeLists.txt").read_text(encoding="utf-8")
_cv = ".".join(_re.search(r"CHIAKI_VERSION_%s (\d+)" % k, _cm).group(1) for k in ("MAJOR", "MINOR", "PATCH"))
app.setApplicationVersion("%s (chiaki-ng %s)" % ((repo / "dekkimon.version").read_text().split()[0], _cv))
engine = QQmlApplicationEngine()
engine.addImageProvider("svg", Svg())
engine.addImageProvider("qr", Qr())
engine.addImportPath(str(qml_out))
engine.load(QUrl.fromLocalFile(str(qml_out / "Preview.qml")))
assert engine.rootObjects(), errors
window = engine.rootObjects()[0]

def grab(name):
    window.grabWindow().save(str(out / f"{name}.png"))
    print("wrote", out / f"{name}.png")

def key(k, wait=140):
    QTest.keyClick(window, k)
    QTest.qWait(wait)

def child(name):
    return window.findChild(QObject, name)

scenes = sys.argv[1:] or ["globe", "home", "connect", "quick", "quick-stream", "pin"]

from PySide6.QtCore import QMetaObject, Q_ARG
def show(name):
    QMetaObject.invokeMethod(window, "show", Q_ARG("QVariant", name))
    QTest.qWait(300)
    window.requestActivate()
    home = child("home")
    if home is not None:
        QMetaObject.invokeMethod(home, "forceActiveFocus")
    QTest.qWait(50)

def record_connect():
    """Deterministic 30 fps recording: home -> cross-fade -> connecting -> reveal -> stream."""
    import math
    show("sequence")
    home, overlay = child("home"), child("connect")
    home_globe = home.findChild(QObject, "homeGlobe")
    globe = overlay.findChild(QObject, "connectGlobe")
    for g in (home_globe, globe):
        g.setProperty("manual", True)
    frames = out / "connect-frames"
    shutil.rmtree(frames, ignore_errors=True); frames.mkdir()
    dt = 1 / 30
    state = {"n": 0, "spin": 0.6, "pulse": 0.0, "phase": 0.0, "energy": 0.0}
    def tick(energy_target=None, reveal=None):
        e = state["energy"]
        if energy_target is not None:
            # Same easing speed as the QML Behavior (900 ms InOutSine), approximated per frame.
            step = dt / 0.9
            e = min(1.0, e + step) if energy_target > e else max(0.0, e - step)
        state["energy"] = e
        eased = 0.5 - 0.5 * math.cos(math.pi * e)
        state["spin"] += dt * (0.07 + 0.22 * eased)
        state["pulse"] += dt * (1.9 + 2.9 * eased)
        state["phase"] += dt
        for g in (home_globe, globe):
            g.setProperty("spin", state["spin"]); g.setProperty("pulse", state["pulse"])
            g.setProperty("phase", state["phase"]); g.setProperty("energy", eased)
        if reveal is not None:
            globe.setProperty("reveal", reveal)
        QTest.qWait(1)
        window.grabWindow().save(str(frames / f"{state['n']:04d}.png")); state["n"] += 1
    for g in (home_globe, globe):
        assert g.property("shaderReady"), "globe shader failed to load - preview would show the fallback"
    for _ in range(45): tick(0)                       # home, idle
    grab("sequence-home")
    for i in range(1, 7):                             # Connect pressed: 200 ms cross-fade
        overlay.setProperty("opacity", i / 6); tick(1)    # same as Main.qml: old view stays opaque
    home.setProperty("visible", False)
    for i in range(96):                               # connecting
        tick(1)
        if i == 60: grab("connect-connecting")
    overlay.setProperty("streamReady", True)          # first video frame on screen
    for i in range(35):                               # reveal, InQuart over 1.15 s
        x = (i + 1) / 35
        overlay.setProperty("titleOpacity", max(0.0, 1 - x * 4))
        tick(0, reveal=x ** 4)
        if i == 22: grab("connect-reveal-early")
        if i == 30: grab("connect-reveal-late")
    overlay.setProperty("visible", False)
    for _ in range(20): tick(0)
    mp4, gif = out / "portal-connect.mp4", out / "portal-connect.gif"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "30", "-i", str(frames / "%04d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", str(mp4)], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "30", "-i", str(frames / "%04d.png"),
                    "-vf", "fps=20,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=200[p];[b][p]paletteuse=dither=sierra2_4a",
                    str(gif)], check=True)
    print("wrote", mp4, gif, state["n"], "frames")

for scene in scenes:
    if scene == "globe":
        show("globe"); QTest.qWait(800); grab("globe")
    elif scene == "home":
        show("home"); QTest.qWait(900); grab("home")
    elif scene == "quick":
        show("home"); QTest.qWait(300)
        key(Qt.Key_Menu, 450); grab("quick-menu")
        key(Qt.Key_Down); key(Qt.Key_Down); key(Qt.Key_Down, 300); grab("quick-menu-focus")
        key(Qt.Key_Escape, 400)
    elif scene == "quick-stream":
        show("quick-stream"); QTest.qWait(400)
        grab("stream-quick-menu")
        for _ in range(5): key(Qt.Key_Down)
        QTest.qWait(250); grab("stream-quick-menu-scrolled")
        key(Qt.Key_Return, 450); grab("stream-quick-submenu")
        key(Qt.Key_Escape, 400)
    elif scene == "nav":
        # Spatial navigation in the stream menu: tiles side by side, slider keeps left/right.
        show("quick-stream"); QTest.qWait(450)
        def focused():
            item = window.activeFocusItem()
            return (item.property("text") or item.property("accessibleName") or item.objectName()
                    or type(item).__name__) if item else None
        steps = [("start", None), ("right", Qt.Key_Right), ("left", Qt.Key_Left), ("right", Qt.Key_Right),
                 ("down", Qt.Key_Down), ("vol-left", Qt.Key_Left), ("vol-right", Qt.Key_Right),
                 ("down", Qt.Key_Down), ("up", Qt.Key_Up), ("up", Qt.Key_Up)]
        trace = []
        for label, k in steps:
            if k is not None:
                key(k, 160)
            item = window.activeFocusItem()
            v = item.property("value") if item else None
            trace.append((label, focused(), round(v, 1) if isinstance(v, (int, float)) else None))
        for t in trace: print("nav:", t)
        names = [t[1] for t in trace]
        assert names[1] == "Disconnect" and names[2] == "Return to game", names
        assert trace[4][2] is not None, "Down from a tile should land on the volume slider"
        assert trace[5][2] < trace[4][2] and trace[6][2] == trace[4][2], "left/right must adjust the slider"
        assert names[8] in ("Return to game", "Disconnect") or trace[8][2] is not None, names
        key(Qt.Key_Down, 160); key(Qt.Key_Right, 300); grab("nav-stream-menu")
        print("nav: OK")
    elif scene in ("color-hdr", "picture"):
        show(scene); QTest.qWait(500)
        dlg = child("settingsDialog")
        QMetaObject.invokeMethod(dlg.property("mainItem"), "forceActiveFocus")
        QTest.qWait(300)
        def focused():
            item = window.activeFocusItem()
            return (item.property("text") or item.property("accessibleName") or type(item).__name__) if item else None
        grab(f"{scene}-root")
        seen = []
        for _ in range(14):
            it = window.activeFocusItem()
            seen.append((focused(), round(it.mapToScene(it.position() * 0).y()) if it else None)); key(Qt.Key_Down, 120)
        QTest.qWait(250); grab(f"{scene}-scrolled")
        print(scene, "focus walk:", seen)
        # Walk back to the top and open the first choice.
        for _ in range(16): key(Qt.Key_Up, 60)
        key(Qt.Key_Return, 450); grab(f"{scene}-choice")
        key(Qt.Key_Escape, 400)
        print(scene, "after back:", focused())
    elif scene == "settings":
        show("settings"); QTest.qWait(600)
        view = child("appSettings")
        QMetaObject.invokeMethod(view, "focusCurrent"); QTest.qWait(300)
        grab("settings-list")
        def open_row(n, name):
            for _ in range(n): key(Qt.Key_Down, 90)
            key(Qt.Key_Return, 450); grab(name)
        open_row(7, "settings-remote"); key(Qt.Key_Escape, 400)
        for _ in range(9): key(Qt.Key_Up, 60)
        open_row(2, "settings-streaming")
        for _ in range(6): key(Qt.Key_Down, 100)
        QTest.qWait(250); grab("settings-streaming-scrolled"); key(Qt.Key_Escape, 400)
        for _ in range(9): key(Qt.Key_Up, 60)
        open_row(1, "settings-video"); key(Qt.Key_Escape, 400)
        for _ in range(9): key(Qt.Key_Up, 60)
        open_row(4, "settings-consoles"); key(Qt.Key_Escape, 400)
        for _ in range(9): key(Qt.Key_Up, 60)
        open_row(0, "settings-general"); key(Qt.Key_Escape, 400)
    elif scene == "settings-nav":
        show("settings"); QTest.qWait(600)
        view = child("appSettings")
        QMetaObject.invokeMethod(view, "focusCurrent"); QTest.qWait(300)
        def f():
            it = window.activeFocusItem()
            return (it.property("text") or it.property("accessibleName") or type(it).__name__, it.metaObject().className()) if it else None
        print("root:", f())
        key(Qt.Key_Return, 500); print("after open General:", f())
        it = window.activeFocusItem()
        for name in ("title", "source", "items", "isRoot"):
            v = it.property(name)
            print("  page.", name, type(v).__name__, (len(v) if hasattr(v, "__len__") else v))
        for i in range(4):
            key(Qt.Key_Down, 150); print("down", i, f())
        key(Qt.Key_Escape, 450); print("back:", f())
        key(Qt.Key_Down, 120); key(Qt.Key_Down, 120); key(Qt.Key_Down, 120); key(Qt.Key_Return, 500)
        print("audio open:", f())
        for i in range(6):
            key(Qt.Key_Down, 150); print("audio down", i, f())
        key(Qt.Key_Left, 150); print("slider left:", f())
        grab("settings-nav")
    elif scene == "popups":
        show("home"); QTest.qWait(600)
        QMetaObject.invokeMethod(window, "openRemind"); QTest.qWait(500); grab("popup-remind")
        key(Qt.Key_Right, 250); grab("popup-remind-right")
        key(Qt.Key_Escape, 400)
        QMetaObject.invokeMethod(window, "openConfirm"); QTest.qWait(500); grab("popup-confirm")
        key(Qt.Key_Escape, 400)
    elif scene == "psn-phone":
        show("psn-phone"); QTest.qWait(500)
        dlg = child("psnPhone")
        QMetaObject.invokeMethod(dlg, "startServer"); QTest.qWait(300)
        grab("psn-phone-waiting")
        dlg.setProperty("state_", "phone"); QTest.qWait(200); grab("psn-phone-connected")
        dlg.setProperty("state_", "done"); QTest.qWait(200); grab("psn-phone-done")
    elif scene == "pin":
        show("pin"); QTest.qWait(500)
        for k in (Qt.Key_1, Qt.Key_2): key(k, 80)
        key(Qt.Key_Right, 200); grab("pin")
    elif scene == "connect":
        record_connect()
    elif scene == "consoles":
        QMetaObject.invokeMethod(window, "setWifi", Q_ARG("QVariant", "good"))
        show("home"); QTest.qWait(500)
        home = child("home")
        home.setProperty("browsingConsoles", True); QTest.qWait(600); grab("consoles")
        key(Qt.Key_Right, 400); grab("consoles-second")
        key(Qt.Key_Right, 400); grab("consoles-add")
        key(Qt.Key_Right, 400)                     # wraps to the first console
        key(Qt.Key_No, 600); grab("consoles-options"); key(Qt.Key_Escape, 450)
        key(Qt.Key_Yes, 600); grab("consoles-manage"); key(Qt.Key_Escape, 450)
    elif scene == "legacy":
        # Every screen the new UI can still open that predates the Portal redesign.
        for name in ("manual-host", "regist", "profile", "steam-shortcut", "controller-mapping"):
            show(name); QTest.qWait(600); grab(f"legacy-{name}")
            if name == "steam-shortcut":
                QMetaObject.invokeMethod(child("legacy"), "create"); QTest.qWait(600); grab("legacy-steam-progress")
                key(Qt.Key_Escape, 400)
        show("settings"); QTest.qWait(600)
        dlg = child("settingsDialog")
        QMetaObject.invokeMethod(dlg, "openAbout"); QTest.qWait(600); grab("legacy-about")
        key(Qt.Key_Escape, 400)
        view = child("appSettings")
        QMetaObject.invokeMethod(window, "openKeyRows", Q_ARG("QVariant", view)); QTest.qWait(600); grab("legacy-key-mapping")
        key(Qt.Key_Return, 500); grab("legacy-key-capture")
        key(Qt.Key_K, 500)
        show("controller-mapping"); QTest.qWait(600)
        for _ in range(3): key(Qt.Key_Down, 120)
        key(Qt.Key_Return, 500); grab("legacy-controller-button")
        key(Qt.Key_Return, 500); grab("legacy-controller-capture")
    elif scene in ("menus", "menus-weak"):
        preset = "weak" if scene == "menus-weak" else "good"
        tag = "-weak" if preset == "weak" else ""
        QMetaObject.invokeMethod(window, "setWifi", Q_ARG("QVariant", preset))
        show("home"); QTest.qWait(900); grab(f"new-home{tag}")
        for name, call in (("conn-stream", None), ("conn-stream", "openConnectionPage"), ("home-menu", None),
                           ("home-menu", "openConnectionPage"), ("picture-page", "openPicturePage"), ("leave", "leave")):
            if preset == "weak" and name in ("picture-page", "leave", "home-menu") and call != "openConnectionPage":
                continue
            show(name); QTest.qWait(400)
            menu = child("streamMenu")
            QTest.qWait(450)   # past the menu's input guard
            if call:
                QMetaObject.invokeMethod(menu, call); QTest.qWait(500)
            label = {None: "menu", "openConnectionPage": "connection", "openPicturePage": "picture", "leave": "leave"}[call]
            ctx = "stream" if name != "home-menu" else "home"
            grab(f"new-{ctx}-{label}{tag}")
            if call == "openConnectionPage":
                for _ in range(6): key(Qt.Key_Down, 90)
                QTest.qWait(300); grab(f"new-{ctx}-{label}-scrolled{tag}")

print("errors:", [e for e in errors if "qsb" in e or "Shader" in e or "TypeError" in e or "ReferenceError" in e])
