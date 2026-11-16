import QtQuick
import QtQuick.Controls
import org.streetpea.chiaking
import "controls" as C
import "controls/ConnectionText.js" as Conn

// Shared top bar of the home and consoles screens: icon tab pill on the left, connection
// chip and clock on the right. currentAction: 0 = Remote Play, 1 = Consoles, 2 = Quick menu.
Item {
    id: bar
    property int currentAction: 0
    property bool controllerConnected: false
    property bool compact: false
    property real margin: 40
    property string clockText: Qt.formatTime(new Date(), "h:mm AP")
    signal homeRequested()
    signal consolesRequested()
    signal quickMenuRequested()
    signal connectionRequested()
    height: tabs.y + tabs.height

    Timer { interval: 15000; running: bar.visible; repeat: true; triggeredOnStart: true
        onTriggered: bar.clockText = Qt.formatTime(new Date(), "h:mm AP") }

    Rectangle {
        id: tabs
        x: bar.margin; y: bar.margin - 8
        height: 68; width: tabRow.width + 14
        radius: height / 2
        color: "#d0141822"
        border.width: 1; border.color: "#262d39"
        Row {
            id: tabRow
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: [
                    { icon: "controller", label: qsTr("Remote Play") },
                    { icon: "console", label: qsTr("Consoles") },
                    { icon: "settings", label: qsTr("Quick menu") }
                ]
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool current: bar.currentAction === index
                    width: 56; height: 56; radius: 28
                    color: current ? "#3f4859" : tabMouse.containsMouse ? "#262d39" : "transparent"
                    border.width: current && bar.controllerConnected ? 2 : 0
                    border.color: "#f2f0ff"
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Image {
                        anchors.centerIn: parent
                        width: 30; height: 30
                        sourceSize: Qt.size(68, 68)
                        source: "qrc:/icons/portal/" + tab.modelData.icon + ".svg"
                        opacity: tab.current ? 1 : 0.72
                    }
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.label
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: [bar.homeRequested, bar.consolesRequested, bar.quickMenuRequested][tab.index]()
                    }
                }
            }
        }
    }
    Label {
        anchors.left: tabs.right; anchors.leftMargin: 14
        anchors.verticalCenter: tabs.verticalCenter
        text: [qsTr("Remote Play"), qsTr("Consoles"), qsTr("Quick menu")][Math.max(0, Math.min(2, bar.currentAction))]
        color: "#cfccd9"
        font.pixelSize: 16
        visible: !bar.compact && bar.currentAction !== 0
    }

    // Status corner: connection chip (tap for details) and clock.
    Row {
        anchors.right: parent.right; anchors.rightMargin: bar.margin
        anchors.verticalCenter: tabs.verticalCenter
        spacing: 18
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Conn.shown(Chiaki.wifi)
            height: 40; radius: 20
            width: linkRow.width + 28
            color: linkMouse.pressed ? "#323b4a" : linkMouse.containsMouse ? "#232a36" : "#a0141822"
            border.width: 1; border.color: "#262d39"
            Row {
                id: linkRow
                anchors.centerIn: parent
                spacing: 10
                C.SignalBars {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 18
                    level: Conn.bars(Chiaki.wifi)
                    wired: !!Chiaki.wifi && Chiaki.wifi.kind === "wired"
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Conn.qualityLabel(Chiaki.wifi)
                    color: "#ecebf3"
                    font.pixelSize: bar.compact ? 14 : 16
                }
            }
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Connection: %1").arg(Conn.qualityLabel(Chiaki.wifi))
            MouseArea { id: linkMouse; anchors.fill: parent; hoverEnabled: true; onClicked: bar.connectionRequested() }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: bar.clockText
            color: "#ffffff"
            font.pixelSize: bar.compact ? 18 : 22
        }
    }
}
