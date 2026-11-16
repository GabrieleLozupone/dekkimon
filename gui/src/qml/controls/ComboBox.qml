import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "SpatialNav.js" as Nav

ComboBox {
    id: control
    font.pixelSize: 16
    leftPadding: 16
    rightPadding: 36
    topPadding: 12
    bottomPadding: 12
    Material.foreground: enabled ? "#f4f4f6" : "#777b88"
    background: Rectangle {
        implicitHeight: 52
        radius: 14
        color: control.activeFocus ? "#24344c" : control.hovered ? "#222833" : "#1a1e27"
        border.width: control.activeFocus ? 2 : 0
        border.color: "#e3efff"
        opacity: control.enabled ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    property bool firstInFocusChain: false
    property bool lastInFocusChain: false
    implicitContentWidthPolicy: ComboBox.WidestText

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Down:
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (!popup.visible) {
                Nav.handleKey(control, event, true);
                event.accepted = true;
            }
            break;
        case Qt.Key_Return:
            if (popup.visible) {
                activated(highlightedIndex);
                popup.close();
            } else {
                popup.open();
            }
            event.accepted = true;
            break;
        }
    }

    Keys.onReleased: (event) => {
        if (event.key == Qt.Key_Return)
            event.accepted = true;
    }
}
