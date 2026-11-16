import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Controls.Material
import "SpatialNav.js" as Nav

// Action pill for Portal-style pop-ups. The focused button is white and shows ✕ (pressing ✕
// activates it); other buttons show their own shortcut glyph (e.g. ○ for "No").
QQC.Button {
    id: control
    property string glyph: ""
    readonly property string shownGlyph: activeFocus ? "cross" : glyph
    readonly property string glyphSource: shownGlyph && typeof root !== "undefined" && root.controllerButton
        ? root.controllerButton(shownGlyph) : ""
    implicitHeight: 56
    leftPadding: glyphSource ? 18 : 28
    rightPadding: 28
    font.pixelSize: 17
    focusPolicy: Qt.StrongFocus
    background: Rectangle {
        radius: height / 2
        color: control.activeFocus ? "#ffffff" : control.hovered ? "#2d3544" : "#232a36"
        border.width: control.activeFocus ? 3 : 0
        border.color: "#8fb8ff"
        opacity: control.enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    contentItem: Row {
        spacing: 10
        // Glyphs are white discs with the letter cut out; on the white focused pill a dark disc
        // behind them keeps the letter readable.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!control.glyphSource
            width: 28; height: 28; radius: 14
            color: control.activeFocus ? "#101116" : "transparent"
            Image {
                id: glyphImage
                anchors.centerIn: parent
                width: control.activeFocus ? 22 : 26; height: width
                sourceSize: Qt.size(52, 52)
                source: control.glyphSource
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            font: control.font
            color: control.activeFocus ? "#101116" : "#f4f2fa"
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            control.clicked();
            event.accepted = true;
        } else if (Nav.handleKey(control, event, true)) {
            event.accepted = true;
        }
    }
}
