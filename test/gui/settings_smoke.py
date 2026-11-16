"""Validate shared dialog styling, category navigation and QML compilation.
Run: uv run --with PySide6 python test/gui/settings_smoke.py
The preview uses real UI components with sample controls, not a live console.
"""
import runpy
from pathlib import Path
scope = runpy.run_path(str(Path(__file__).with_name("mainview_smoke.py")))
globals().update({key: value for key, value in scope.items() if not key.startswith("__")})
from PySide6.QtQml import QQmlComponent
# Copy all source components to resolve local imports; use the mock backend from the home test.
for source in [*(repo / "gui/src/qml").rglob("*.qml"), *(repo / "gui/src/qml").rglob("*.js")]:
 destination = out / source.relative_to(repo / "gui/src/qml")
 destination.parent.mkdir(parents=True, exist_ok=True)
 destination.write_text(source.read_text(encoding="utf-8").replace("qrc:/icons/", (repo / "gui/res").as_uri()+"/"),encoding="utf-8")
engine.clearComponentCache()
for name in ["SettingsDialog.qml","ManualHostDialog.qml","RegistDialog.qml","StreamView.qml","StreamMenuWindow.qml","ConfirmDialog.qml","RemindDialog.qml"]:
 component = QQmlComponent(engine, QUrl.fromLocalFile(str(out/name)))
 assert not component.isError(), (name, [e.toString() for e in component.errors()])
(out/"SettingsPreview.qml").write_text("""
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "controls" as C
ApplicationWindow {
 id: root
 objectName: "settingsPreview"
 width: 1280; height: 800; visible: true
 Material.theme: Material.Dark
 property bool closed: false
 function closeDialog() { closed = true; }
 DialogView {
  id: page
  anchors.fill: parent
  title: qsTr("Settings")
  header: qsTr("L1 / R1: change category. Settings are saved automatically.")
  buttonVisible: false
  Keys.onPressed: event => {
   if (event.key === Qt.Key_PageDown) { nav.incrementCurrentIndex(); event.accepted = true; }
   else if (event.key === Qt.Key_PageUp) { nav.decrementCurrentIndex(); event.accepted = true; }
  }
  Item {
   SettingsNavigation {
    id: nav; objectName: "navigation"
    compact: root.width < 1000
    width: compact ? parent.width : 190
    height: compact ? 56 : parent.height
   }
   ColumnLayout {
    anchors.left: nav.compact ? parent.left : nav.right
    anchors.leftMargin: nav.compact ? 0 : 28
    anchors.right: parent.right
    anchors.top: nav.compact ? nav.bottom : parent.top
    anchors.topMargin: 16
    spacing: 24
    Label { text: nav.categories[nav.currentIndex]; font.pixelSize: 26; font.bold: true; color: "#f4f4f6" }
    Label { text: nav.descriptions[nav.currentIndex]; color: "#a7a9b5"; font.pixelSize: 15 }
    GridLayout {
     columns: 2; rowSpacing: 20; columnSpacing: 36
     Label { text: qsTr("When you disconnect"); color: "#c4c5cd" }
     C.ComboBox { objectName: "choice"; model: ["Ask every time", "Keep console on", "Rest mode"]; Layout.preferredWidth: 260; firstInFocusChain: true }
     Label { text: qsTr("Console address"); color: "#c4c5cd" }
     C.TextField { objectName: "address"; placeholderText: "IP address or hostname"; Layout.preferredWidth: 260 }
     Item { width: 1; height: 1 }
     C.CheckBox { objectName: "check"; text: qsTr("Confirm before disconnecting"); checked: true }
     Item { width: 1; height: 1 }
     C.Button { text: qsTr("Manage consoles"); lastInFocusChain: true }
    }
   }
  }
 }
}
""",encoding="utf-8")
engine.load(QUrl.fromLocalFile(str(out/"SettingsPreview.qml")))
window=next(w for w in engine.rootObjects() if w.objectName()=="settingsPreview")
window.requestActivate()
settle()
window.grabWindow().save(str(out/"settings-style-1280.png"))
from PySide6.QtCore import QObject
nav=window.findChild(QObject,"navigation")
assert nav is not None, errors
choice=window.findChild(QObject,"choice")
choice.forceActiveFocus(Qt.TabFocusReason)
QTest.keyClick(window,Qt.Key_PageDown);settle()
assert nav.property("currentIndex")==1
QTest.keyClick(window,Qt.Key_PageUp);settle()
assert nav.property("currentIndex")==0
QTest.keyClick(window,Qt.Key_Return);settle()
QTest.keyClick(window,Qt.Key_Down);QTest.keyClick(window,Qt.Key_Return);settle()
QTest.keyClick(window,Qt.Key_Down);settle()
address=window.findChild(QObject,"address")
address.forceActiveFocus(Qt.TabFocusReason)
settle()
QTest.keyClick(window,Qt.Key_Return);settle()
assert not address.property("readOnly")
QTest.keyClick(window,Qt.Key_Escape);settle()
assert address.property("readOnly") and not window.property("closed")
window.setWidth(800);window.setHeight(600);settle()
assert nav.property("compact")
window.grabWindow().save(str(out/"settings-style-800.png"))
assert not errors, "\n".join(errors)
print("PASS: settings/setup/stream QML compile; category switching; field edit/cancel; shared-control rendering.")