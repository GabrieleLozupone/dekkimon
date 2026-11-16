import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "SpatialNav.js" as Nav

RadioButton {
    id: control
    property bool firstInFocusChain: false
    property bool lastInFocusChain: false

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
        case Qt.Key_Down:
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (Nav.handleKey(control, event, true))
                event.accepted = true;
            break;
        case Qt.Key_Return:
            if (visualFocus) {
                toggle();
                toggled();
            }
            event.accepted = true;
            break;
        }
    }
}
