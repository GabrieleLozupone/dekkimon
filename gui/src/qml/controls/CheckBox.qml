import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "SpatialNav.js" as Nav

CheckBox {
    id: control
    font.pixelSize: 16
    spacing: 12
    Material.accent: "#379aff"
    leftPadding: 14
    rightPadding: 14
    topPadding: 10
    bottomPadding: 10
    background: Rectangle {
        implicitHeight: 52
        radius: 14
        color: control.activeFocus ? "#24344c" : control.hovered ? "#222833" : "transparent"
        border.width: control.activeFocus ? 2 : 0
        border.color: "#e3efff"
    }
    // Pill switch, as in the quick menu.
    indicator: Rectangle {
        x: control.leftPadding
        y: (control.height - height) / 2
        implicitWidth: 48; implicitHeight: 28
        radius: 14
        color: control.checked ? "#4c9dff" : "#444b58"
        opacity: control.enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            width: 22; height: 22; radius: 11
            y: 3; x: control.checked ? parent.width - width - 3 : 3
            color: control.checked ? "#ffffff" : "#d6d4de"
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    property bool firstInFocusChain: false
    property bool lastInFocusChain: false
    property bool sendOutput: false

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Down:
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (Nav.handleKey(control, event, true) && !sendOutput)
                event.accepted = true;
            break;
        case Qt.Key_Return:
            if (activeFocus) {
                toggle();
                clicked();
            }
            event.accepted = true;
            break;
        }
    }
}
