import QtQuick
import QtQuick.Controls
import org.streetpea.chiaking

// Home screen: icon tab bar, status corner, big call to action, particle globe and
// controller hints. Navigation lives in MainView; this item only renders state
// (currentAction: 0 = Remote Play / connect, 1 = consoles tab, 2 = quick menu).
Item {
    id: homeView
    property string consoleName: ""
    property string connectText: qsTr("Connect")
    property string statusText: ""
    property int currentAction: 0
    // 0..1 while the quick menu slides in; the globe moves left to stay in view.
    property real sidebar: 0
    property bool controllerConnected: false
    property alias globe: globe
    readonly property bool compact: width < 800
    readonly property real margin: compact ? 28 : 40
    signal homeRequested()
    signal connectRequested()
    signal consolesRequested()
    signal quickMenuRequested()
    signal connectionRequested()

    function glyph(name) {
        if (name === "options")
            return "qrc:/icons/portal/options-badge.svg";
        if (["l1", "r1", "l3", "r3"].indexOf(name) >= 0)
            return "qrc:/icons/" + name + ".svg";
        return typeof root !== "undefined" && root.controllerButton ? root.controllerButton(name) : "";
    }

    PortalGlobe {
        id: globe
        objectName: "homeGlobe"
        anchors.fill: parent
        running: homeView.visible
        centerX: width * 0.5
        centerY: height * 0.53
        radius: Math.min(width, height) * 0.36
        MouseArea {
            // The globe itself is the play button for touch and mouse.
            x: globe.centerX - globe.radius; y: globe.centerY - globe.radius
            width: globe.radius * 2; height: width
            cursorShape: Qt.PointingHandCursor
            onClicked: homeView.connectRequested()
        }
    }

    PortalTopBar {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        currentAction: homeView.currentAction
        controllerConnected: homeView.controllerConnected
        compact: homeView.compact
        margin: homeView.margin
        onHomeRequested: homeView.homeRequested()
        onConsolesRequested: homeView.consolesRequested()
        onQuickMenuRequested: homeView.quickMenuRequested()
        onConnectionRequested: homeView.connectionRequested()
    }

    Column {
        anchors.left: parent.left; anchors.leftMargin: homeView.margin + 8
        anchors.top: parent.top; anchors.topMargin: parent.height * 0.17
        width: Math.max(200, homeView.width * 0.5 - x)
        spacing: 10
        Label {
            width: parent.width
            text: homeView.consoleName ? qsTr("Connect to “%1”").arg(homeView.consoleName) : qsTr("Your PlayStation, wherever you play.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.pixelSize: homeView.compact ? 26 : 34
            font.weight: Font.Light
            color: "#f5f4fb"
        }
        Label {
            width: parent.width
            visible: text
            text: homeView.statusText
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pixelSize: homeView.compact ? 14 : 17
            color: "#a9a5ba"
        }
    }

    // Controller hints (also tap targets).
    Row {
        anchors.left: parent.left; anchors.leftMargin: homeView.margin
        anchors.bottom: parent.bottom; anchors.bottomMargin: homeView.margin - 6
        spacing: 10
        component Hint: Rectangle {
            id: hint
            property var glyphs: []
            property string label
            property bool primary: false
            signal activated()
            height: 40; radius: 20
            width: hintRow.width + 28
            color: primary ? (hintMouse.pressed ? "#323b4a" : "#232a36") : hintMouse.containsMouse ? "#1e232c" : "transparent"
            border.width: primary && homeView.currentAction === 0 && homeView.controllerConnected ? 2 : 0
            border.color: "#f2f0ff"
            Row {
                id: hintRow
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: hint.glyphs
                    Image {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; sourceSize: Qt.size(48, 48)
                        source: homeView.glyph(modelData)
                    }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hint.label
                    color: "#ecebf3"
                    font.pixelSize: homeView.compact ? 14 : 17
                }
            }
            MouseArea { id: hintMouse; anchors.fill: parent; hoverEnabled: true; onClicked: hint.activated() }
        }
        Hint { primary: true; glyphs: ["cross"]; label: homeView.connectText; onActivated: homeView.connectRequested() }
        Hint { glyphs: ["l1", "r1"]; label: qsTr("Switch tabs"); onActivated: homeView.consolesRequested() }
        Hint { glyphs: ["options"]; label: qsTr("Quick menu"); onActivated: homeView.quickMenuRequested() }
    }
}
