import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "SpatialNav.js" as Nav

TextField {
    id: control
    font.pixelSize: 16
    color: enabled ? "#f4f4f6" : "#777b88"
    placeholderTextColor: "#9295a3"
    leftPadding: 16
    rightPadding: 16
    topPadding: 12
    bottomPadding: 12
    background: Rectangle {
        implicitHeight: 52
        radius: 14
        color: control.activeFocus ? "#24344c" : "#1a1e27"
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? "#e3efff" : "#2b3140"
        opacity: control.enabled ? 1 : 0.5
    }
    property bool firstInFocusChain: false
    property bool lastInFocusChain: false
    property bool sendOutput: false
    readOnly: true

    onActiveFocusChanged: {
        if (!activeFocus)
            readOnly = true;
    }

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Down:
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (readOnly && Nav.handleKey(control, event, true) && !sendOutput)
                event.accepted = true;
            break;
        case Qt.Key_Return:
            if (readOnly) {
                readOnly = false;
                Qt.inputMethod.show();
                event.accepted = true;
            } else {
                readOnly = true;
            }
            break;
        case Qt.Key_Escape:
            if (!readOnly) {
                readOnly = true;
                editingFinished();
                event.accepted = true;
            }
            break;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: parent.readOnly
        onClicked: {
            parent.forceActiveFocus(Qt.TabFocusReason);
            parent.readOnly = false;
            Qt.inputMethod.show();
        }
    }
}
