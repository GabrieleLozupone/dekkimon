import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.streetpea.chiaking
import "controls" as C
import "controls/ConnectionText.js" as Conn

// Connection details, pushed onto the quick menu's page stack: what stream quality to
// expect where you are, the measured link, advice that applies now, and what each
// quality level needs. Up/Down scroll; Back returns.
FocusScope {
    id: page
    property bool streaming: false
    readonly property var wifi: Chiaki.wifi
    readonly property var tipList: Conn.tips(wifi, Chiaki.settings)
    signal backRequested()

    Keys.onEscapePressed: backRequested()
    Keys.onBackPressed: backRequested()
    Keys.onUpPressed: scroll.contentY = Math.max(0, scroll.contentY - 80)
    Keys.onDownPressed: scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, scroll.contentY + 80))
    Component.onCompleted: Qt.callLater(() => page.forceActiveFocus(Qt.TabFocusReason))

    RowLayout {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: 22; anchors.rightMargin: 22
        spacing: 14
        RoundButton {
            Layout.preferredWidth: 46; Layout.preferredHeight: 46
            focusPolicy: Qt.NoFocus
            icon.source: "qrc:/icons/portal/back.svg"
            icon.width: 22; icon.height: 22
            icon.color: "#ffffff"
            background: Rectangle { radius: 23; color: "#232a36" }
            onClicked: page.backRequested()
            Accessible.name: qsTr("Back")
        }
        Label { text: qsTr("Connection"); font.pixelSize: 26; color: "#ffffff" }
        Item { Layout.fillWidth: true }
    }

    Flickable {
        id: scroll
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom }
        anchors.leftMargin: 22; anchors.rightMargin: 22; anchors.topMargin: 14
        contentHeight: body.height + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Behavior on contentY { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: body
            width: parent.width
            spacing: 14

            // Verdict card.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: verdictColumn.implicitHeight + 36
                radius: 18
                color: "#1a1e27"
                ColumnLayout {
                    id: verdictColumn
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    anchors.leftMargin: 20; anchors.rightMargin: 20
                    spacing: 8
                    RowLayout {
                        spacing: 14
                        C.SignalBars {
                            Layout.preferredWidth: 34; Layout.preferredHeight: 26
                            level: Conn.bars(page.wifi)
                            wired: !!page.wifi && page.wifi.kind === "wired"
                        }
                        Label { text: Conn.qualityLabel(page.wifi); font.pixelSize: 28; color: "#ffffff" }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: Conn.verdict(page.wifi)
                        wrapMode: Text.WordWrap
                        font.pixelSize: 16
                        color: "#c9c5d8"
                    }
                }
            }

            // Measured values.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: facts.implicitHeight + 24
                radius: 18
                color: "#1a1e27"
                GridLayout {
                    id: facts
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    anchors.leftMargin: 20; anchors.rightMargin: 20
                    columns: 2
                    rowSpacing: 10; columnSpacing: 16
                    component Key: Label { color: "#a9a5ba"; font.pixelSize: 15 }
                    component Val: Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; color: "#ffffff"; font.pixelSize: 15; elide: Text.ElideRight }
                    readonly property bool isWifi: !!page.wifi && page.wifi.kind === "wifi"

                    Key { text: qsTr("Signal"); visible: facts.isWifi }
                    Val { text: page.wifi && page.wifi.signalDbm ? qsTr("%1 dBm").arg(page.wifi.signalDbm) : "–"; visible: facts.isWifi }
                    Key { text: qsTr("Wi-Fi"); visible: facts.isWifi }
                    Val { text: Conn.band(page.wifi) || "–"; visible: facts.isWifi }
                    Key { text: qsTr("Link speed"); visible: facts.isWifi }
                    Val { text: page.wifi && page.wifi.linkMbps > 0 ? qsTr("%1 Mbit/s").arg(Math.round(page.wifi.linkMbps)) : "–"; visible: facts.isWifi }
                    Key { text: qsTr("Your bitrate") }
                    Val {
                        readonly property int mine: Conn.bitrateSetting(Chiaki.settings)
                        readonly property bool tooHigh: !!page.wifi && page.wifi.recommendedBitrate > 0 && mine > page.wifi.recommendedBitrate + 2
                        text: qsTr("%1 Mbps").arg(mine) + (tooHigh ? qsTr("  (above %1)").arg(page.wifi.recommendedBitrate) : "")
                        color: tooHigh ? "#f0c585" : "#ffffff"
                    }
                    Key { text: qsTr("Stream now"); visible: page.streaming && !!Chiaki.session }
                    Val {
                        visible: page.streaming && !!Chiaki.session
                        text: Chiaki.session ? qsTr("%1 Mbps · %2% loss").arg(Number(Chiaki.session.measuredBitrate || 0).toFixed(1))
                                                   .arg((Number(Chiaki.session.averagePacketLoss || 0) * 100).toFixed(1)) : ""
                    }
                }
            }

            // Advice that applies now.
            Label {
                visible: page.tipList.length > 0
                Layout.topMargin: 4
                text: qsTr("What would help")
                font.pixelSize: 18; color: "#ffffff"
            }
            Repeater {
                model: page.tipList
                Rectangle {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: tipText.implicitHeight + 24
                    radius: 14
                    color: "#2a2418"
                    border.width: 1; border.color: "#4a3d22"
                    Label {
                        id: tipText
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        text: modelData
                        wrapMode: Text.WordWrap
                        font.pixelSize: 14
                        color: "#f1e6cf"
                    }
                }
            }

            // Reference table.
            Label {
                Layout.topMargin: 4
                text: qsTr("What each level needs")
                font.pixelSize: 18; color: "#ffffff"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: levelsGrid.implicitHeight + 24
                radius: 18
                color: "#1a1e27"
                ColumnLayout {
                    id: levelsGrid
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    anchors.leftMargin: 16; anchors.rightMargin: 16
                    spacing: 10
                    RowLayout {
                        spacing: 12
                        Label { Layout.preferredWidth: 118; text: qsTr("Level"); color: "#8f8ba0"; font.pixelSize: 13 }
                        Label { Layout.fillWidth: true; text: qsTr("Link speed"); color: "#8f8ba0"; font.pixelSize: 13 }
                        Label { text: qsTr("Bitrate"); color: "#8f8ba0"; font.pixelSize: 13 }
                    }
                    Repeater {
                        model: Conn.levels()
                        delegate: Rectangle {
                            id: levelRow
                            required property var modelData
                            readonly property bool here: !!page.wifi && page.wifi.kind === "wifi" && page.wifi.quality === modelData.level
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 8
                            color: here ? "#24344c" : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6; anchors.rightMargin: 6
                                spacing: 12
                                RowLayout {
                                    Layout.preferredWidth: 112
                                    spacing: 8
                                    C.SignalBars { Layout.preferredWidth: 16; Layout.preferredHeight: 13; level: levelRow.modelData.level }
                                    Label { text: levelRow.modelData.label; font.pixelSize: 14; color: levelRow.here ? "#ffffff" : "#c9c5d8" }
                                    Item { Layout.fillWidth: true }
                                }
                                Label { Layout.fillWidth: true; text: levelRow.modelData.link; font.pixelSize: 14; color: levelRow.here ? "#ffffff" : "#c9c5d8" }
                                Label { text: levelRow.modelData.bitrate; font.pixelSize: 14; color: levelRow.here ? "#ffffff" : "#c9c5d8" }
                            }
                        }
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("Link speed is how fast your Wi-Fi radio talks to the router; keep the stream under about a fifth of it. An 80 MHz channel on 5 GHz roughly doubles it.")
                wrapMode: Text.WordWrap
                font.pixelSize: 13
                color: "#8f8ba0"
            }
        }
    }
}
