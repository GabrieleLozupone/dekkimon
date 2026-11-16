import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "SpatialNav.js" as Nav

ToolButton {
    id: control
    font.pixelSize: 16
    Material.foreground: activeFocus || checked ? "#101116" : "#f4f4f6"
    background: Rectangle {
        implicitWidth: 76
        implicitHeight: 44
        radius: 22
        color: control.activeFocus || control.checked ? "#ffffff" : control.hovered ? "#30333e" : "#22242e"
        border.width: control.activeFocus ? 2 : 0
        border.color: "#379aff"
        opacity: control.enabled ? 1 : 0.4
    }
    Keys.onPressed: (event) => {
        if (Nav.handleKey(control, event, true))
            event.accepted = true;
    }
}
