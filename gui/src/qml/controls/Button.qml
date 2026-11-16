import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "SpatialNav.js" as Nav

Button {
    id: control
    leftPadding: 24
    rightPadding: 24
    topPadding: 12
    bottomPadding: 12
    font.pixelSize: 16
    Material.foreground: enabled ? (activeFocus || highlighted ? "#101116" : "#f4f4f6") : "#777b88"
    background: Rectangle {
        implicitHeight: 46
        radius: height / 2
        color: control.activeFocus || control.highlighted ? "#ffffff" : control.hovered ? "#30333e" : "#22242e"
        border.width: control.activeFocus ? 3 : 1
        border.color: control.activeFocus ? "#8fb8ff" : "#393c48"
        opacity: control.enabled ? 1 : 0.5
    }
    property bool firstInFocusChain: false
    property bool lastInFocusChain: false
    property bool sendOutput: false

    Material.background: activeFocus ? Material.accent : undefined

    Component.onDestruction: {
        if (activeFocus) {
            let item = nextItemInFocusChain();
            if (item)
                item.forceActiveFocus(Qt.TabFocusReason);
        }
    }

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
                clicked();
            }
            event.accepted = true;
            break;
        }
    }
}
