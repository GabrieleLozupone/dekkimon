import QtQuick

// Four rising bars for Chiaki.wifi.quality (0 = none .. 4 = excellent). The bars show
// streaming quality, not raw signal strength, so they agree with the verdict text.
Item {
    id: bars
    property int level: 0
    property bool wired: false
    implicitWidth: 22
    implicitHeight: 18

    function colorFor(level) {
        if (level >= 3) return "#eef4ff";
        if (level === 2) return "#f0c585";
        return "#ff8a80";
    }

    Row {
        anchors.bottom: parent.bottom
        spacing: Math.max(1, Math.round(bars.width / 11))
        visible: !bars.wired
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: (bars.width - 3 * parent.spacing) / 4
                height: bars.height * (index + 1) / 4
                anchors.bottom: parent.bottom
                radius: Math.min(2, width / 2)
                color: index < bars.level ? bars.colorFor(bars.level) : "#4a505c"
            }
        }
    }
    // Wired: a small plug-shaped glyph instead of bars.
    Item {
        anchors.fill: parent
        visible: bars.wired
        Rectangle { x: parent.width * 0.2; width: parent.width * 0.6; height: parent.height * 0.5; y: parent.height * 0.1; radius: 2; color: "#eef4ff" }
        Rectangle { x: parent.width * 0.32; width: 2; height: parent.height * 0.18; y: 0; color: "#eef4ff" }
        Rectangle { x: parent.width * 0.6; width: 2; height: parent.height * 0.18; y: 0; color: "#eef4ff" }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 2; y: parent.height * 0.6; height: parent.height * 0.4; color: "#eef4ff" }
    }
}
