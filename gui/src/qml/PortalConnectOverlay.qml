import QtQuick
import QtQuick.Controls

// Connection screen: the globe pulses while the session starts; once the first video
// frame is on screen (streamReady) a hole opens at the globe centre and expands until
// the console UI underneath fills the display.
Item {
    id: overlay
    property string consoleName: ""
    property string statusText: ""
    property bool streamReady: false
    property bool running: true
    readonly property bool revealed: globe.revealed
    readonly property bool compact: width < 800
    property alias globe: globe
    property alias titleOpacity: title.opacity
    signal revealFinished()

    PortalGlobe {
        id: globe
        objectName: "connectGlobe"
        anchors.fill: parent
        // Same geometry as PortalHome so the globe does not jump when the view changes.
        centerX: width * 0.5
        centerY: height * 0.53
        radius: Math.min(width, height) * 0.36
        running: overlay.running && !globe.revealed
        connecting: !overlay.streamReady
        entering: overlay.streamReady
        onRevealFinished: overlay.revealFinished()
    }

    Column {
        id: title
        anchors.left: parent.left; anchors.top: parent.top
        // Matches the PortalHome title so the cross-fade does not shift the text.
        anchors.leftMargin: overlay.compact ? 36 : 48
        anchors.topMargin: overlay.height * 0.17
        spacing: 10
        opacity: overlay.streamReady ? 0 : 1
        Behavior on opacity { enabled: !globe.manual; NumberAnimation { duration: 260 } }
        Label {
            text: overlay.consoleName ? qsTr("Connecting to “%1”").arg(overlay.consoleName) : qsTr("Connecting…")
            textFormat: Text.PlainText
            color: "#f5f4fb"
            font.pixelSize: overlay.compact ? 26 : 36
            font.weight: Font.Light
            width: Math.min(implicitWidth, overlay.width * 0.5)
            elide: Text.ElideRight
        }
        Label {
            text: overlay.statusText || qsTr("Starting Remote Play")
            color: "#a9a5ba"
            font.pixelSize: overlay.compact ? 15 : 18
            SequentialAnimation on opacity {
                running: overlay.running && !overlay.streamReady
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.45; to: 1; duration: 900; easing.type: Easing.InOutSine }
            }
        }
    }
}
