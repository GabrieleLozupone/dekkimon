import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "SpatialNav.js" as Nav

Slider {
    id: control
    Material.accent: activeFocus ? "#ffffff" : "#8fb8ff"
    // Focus ring matching the Portal rows.
    Rectangle {
        z: -2
        anchors.fill: parent
        anchors.margins: -6
        radius: 12
        visible: control.activeFocus
        color: "#24344c"
        border.width: 2
        border.color: "#e3efff"
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
            if (Nav.handleKey(control, event, false) && !sendOutput)
                event.accepted = true;
            break;
        }
    }
}
