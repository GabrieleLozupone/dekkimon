import QtQuick
import QtQuick.Controls
import org.streetpea.chiaking

// Consoles screen: shared top bar, a row of console cards plus an "Add console" card,
// and controller hints. Pure view: selection and actions live in MainView.
// currentIndex runs over entries and one extra slot (== entries.length) for "Add console".
Item {
    id: consoles
    property var entries: []                // [{ backendIndex, host, key }]
    property int currentIndex: 0
    property bool controllerConnected: false
    property bool streamerMode: false
    property var connectionLabel: host => ""
    property var statusLabel: host => ""
    readonly property bool compact: width < 800
    readonly property real margin: compact ? 28 : 40
    readonly property bool addSelected: currentIndex >= entries.length
    readonly property var selectedHost: !addSelected && currentIndex >= 0 ? entries[currentIndex].host : null
    signal selectRequested(int index)
    signal activateRequested(int index)
    signal optionsRequested()
    signal manageRequested()
    signal backRequested()
    signal homeRequested()
    signal quickMenuRequested()
    signal connectionRequested()

    function glyph(name) {
        return typeof root !== "undefined" && root.controllerButton ? root.controllerButton(name) : "";
    }
    function displayName(host) {
        // Manual unregistered entries use their address as their name.
        if (streamerMode && host.name === host.address) return qsTr("Saved console");
        return host.name || (host.ps5 ? "PS5" : qsTr("PlayStation"));
    }
    function statusColor(host) {
        if (host.state === "standby") return "#f0c585";
        if (!host.registered) return "#eef4ff";
        if (host.discovered) return "#7fe0a0";
        if (host.duid) return "#8ab8ff";
        return "#8f8ba0";
    }

    onCurrentIndexChanged: cards.positionViewAtIndex(currentIndex, ListView.Contain)

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#0d1220" }
            GradientStop { position: 0.6; color: "#080a11" }
            GradientStop { position: 1; color: "#06070b" }
        }
    }

    PortalTopBar {
        id: topBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        currentAction: 1
        controllerConnected: consoles.controllerConnected
        compact: consoles.compact
        margin: consoles.margin
        onHomeRequested: consoles.homeRequested()
        onConsolesRequested: {}
        onQuickMenuRequested: consoles.quickMenuRequested()
        onConnectionRequested: consoles.connectionRequested()
    }

    Column {
        id: heading
        x: consoles.margin + 8
        y: Math.max(topBar.height + 20, parent.height * 0.17)
        width: parent.width - 2 * x
        spacing: 8
        Label {
            text: qsTr("Consoles")
            font.pixelSize: consoles.compact ? 26 : 34
            font.weight: Font.Light
            color: "#f5f4fb"
        }
        Label {
            width: parent.width
            text: consoles.entries.length
                ? qsTr("Choose where to play. Consoles in rest mode wake up when you connect.")
                : (Chiaki.discoveryEnabled
                   ? qsTr("Turn on your console or leave it in rest mode on the same network, or sign in to PlayStation Network.")
                   : qsTr("Console discovery is off. Turn it on in Add / manage, or add a console manually."))
            wrapMode: Text.WordWrap
            font.pixelSize: consoles.compact ? 14 : 17
            color: "#a9a5ba"
        }
    }

    ListView {
        id: cards
        anchors { left: parent.left; right: parent.right }
        // Centred in the space between the heading and the hints.
        readonly property real rowTop: heading.y + heading.height + (consoles.compact ? 16 : 24)
        readonly property real rowBottom: consoles.height - consoles.margin - 64
        y: rowTop + Math.max(0, (rowBottom - rowTop - height) / 2)
        height: cardHeight + 24
        // Landscape console cards (standing console on the left), narrower "Add" card.
        readonly property real cardWidth: consoles.compact ? 320 : 400
        readonly property real addWidth: consoles.compact ? 210 : 260
        // Fit between the heading and the hints on small windows.
        readonly property real cardHeight: Math.max(200, Math.min(consoles.compact ? 210 : 270, rowBottom - rowTop - 24))
        orientation: ListView.Horizontal
        spacing: consoles.compact ? 16 : 22
        leftMargin: consoles.margin; rightMargin: consoles.margin
        clip: false
        boundsBehavior: Flickable.StopAtBounds
        model: consoles.entries.length + 1
        currentIndex: consoles.currentIndex
        highlightFollowsCurrentItem: false
        Behavior on contentX { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        delegate: Item {
            id: slot
            required property int index
            readonly property bool isAdd: index >= consoles.entries.length
            readonly property var host: isAdd ? null : consoles.entries[index].host
            readonly property bool selected: index === consoles.currentIndex
            width: isAdd ? cards.addWidth : cards.cardWidth
            height: cards.height

            Rectangle {
                id: card
                width: parent.width
                height: cards.cardHeight
                anchors.verticalCenter: parent.verticalCenter
                radius: 24
                scale: slot.selected ? 1.0 : 0.95
                color: slot.selected ? "#1c2636" : cardMouse.containsMouse ? "#171c26" : "#12161e"
                border.width: slot.selected ? 2 : 1
                border.color: slot.selected ? "#f2f0ff" : "#232a36"
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }

                // Console card: the standing console on the left, details and action on the right.
                Item {
                    anchors.fill: parent
                    anchors.margins: consoles.compact ? 16 : 20
                    visible: !slot.isAdd
                    Image {
                        id: art
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 4 }
                        width: Math.round(height * (slot.host && slot.host.ps5 ? 0.28 : 0.5))
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(Math.round(width * 2), Math.round(height * 2))
                        source: slot.host ? (slot.host.ps5 ? "image://svg/console-ps5v" : "image://svg/console-ps4")
                            + (slot.host.state === "standby" ? "#light_standby" : "#light_on") : ""
                        opacity: slot.selected ? 1 : 0.8
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }
                    Item {
                        anchors { left: art.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: consoles.compact ? 18 : 26 }
                        Column {
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 6 }
                            spacing: 8
                            Label {
                                width: parent.width
                                text: slot.host ? consoles.displayName(slot.host) : ""
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.pixelSize: consoles.compact ? 19 : 23
                                color: "#ffffff"
                            }
                            Row {
                                spacing: 8
                                width: parent.width
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 9; height: 9; radius: 4.5
                                    color: slot.host ? consoles.statusColor(slot.host) : "transparent"
                                }
                                Label {
                                    width: parent.width - 17
                                    text: slot.host ? consoles.statusLabel(slot.host) : ""
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    font.pixelSize: consoles.compact ? 13 : 15
                                    color: "#c9c5d8"
                                }
                            }
                            Label {
                                width: parent.width
                                visible: !!(slot.host && slot.host.app)
                                text: slot.host && slot.host.app ? qsTr("Playing %1").arg(slot.host.app) : ""
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                color: "#8f8ba0"
                            }
                        }
                        // Action pill on every card: filled on the selected one.
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: consoles.compact ? 36 : 42; radius: height / 2
                            color: slot.selected ? "#eef4ff" : "transparent"
                            border.width: slot.selected ? 0 : 1
                            border.color: "#3a4252"
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26; height: 26; radius: 13
                                    color: "#101116"
                                    visible: slot.selected && consoles.controllerConnected
                                    Image {
                                        anchors.centerIn: parent
                                        width: 20; height: 20; sourceSize: Qt.size(48, 48)
                                        source: consoles.glyph("cross")
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: slot.host ? consoles.connectionLabel(slot.host) : ""
                                    font.pixelSize: consoles.compact ? 14 : 16
                                    color: slot.selected ? "#101116" : "#c9c5d8"
                                }
                            }
                        }
                    }
                }

                // "Add console" card.
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 44
                    spacing: 12
                    visible: slot.isAdd
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 72; height: 72; radius: 36
                        color: slot.selected ? "#2a3446" : "#1a1e27"
                        border.width: 1; border.color: "#323a48"
                        Image {
                            anchors.centerIn: parent
                            width: 34; height: 34; sourceSize: Qt.size(68, 68)
                            source: "qrc:/icons/portal/plus.svg"
                        }
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Add console")
                        font.pixelSize: consoles.compact ? 18 : 22
                        color: "#ffffff"
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Sign in to PlayStation Network, find consoles nearby, or enter an address.")
                        wrapMode: Text.WordWrap
                        font.pixelSize: 14
                        color: "#a9a5ba"
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (slot.selected) consoles.activateRequested(slot.index);
                        else consoles.selectRequested(slot.index);
                    }
                }
                Accessible.role: Accessible.Button
                Accessible.name: slot.isAdd ? qsTr("Add console") : (slot.host ? consoles.displayName(slot.host) : "")
            }
        }
    }

    // Controller hints (also tap targets), same style as the home screen.
    Row {
        anchors.left: parent.left; anchors.leftMargin: consoles.margin
        anchors.bottom: parent.bottom; anchors.bottomMargin: consoles.margin - 6
        spacing: 10
        component Hint: Rectangle {
            id: hint
            property string glyphName
            property string label
            property bool primary: false
            signal activated()
            height: 40; radius: 20
            width: hintRow.width + 28
            color: primary ? (hintMouse.pressed ? "#323b4a" : "#232a36") : hintMouse.containsMouse ? "#1e232c" : "transparent"
            Row {
                id: hintRow
                anchors.centerIn: parent
                spacing: 8
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; sourceSize: Qt.size(48, 48)
                    source: consoles.glyph(hint.glyphName)
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hint.label
                    color: "#ecebf3"
                    font.pixelSize: consoles.compact ? 14 : 17
                }
            }
            MouseArea { id: hintMouse; anchors.fill: parent; hoverEnabled: true; onClicked: hint.activated() }
        }
        Hint {
            primary: true; glyphName: "cross"
            label: consoles.addSelected ? qsTr("Add console") : (consoles.selectedHost ? consoles.connectionLabel(consoles.selectedHost) : "")
            onActivated: consoles.activateRequested(consoles.currentIndex)
        }
        Hint { glyphName: "box"; label: qsTr("Options"); visible: !consoles.addSelected; onActivated: consoles.optionsRequested() }
        Hint { glyphName: "pyramid"; label: qsTr("Add / manage"); onActivated: consoles.manageRequested() }
        Hint { glyphName: "moon"; label: qsTr("Back"); onActivated: consoles.backRequested() }
    }
}
