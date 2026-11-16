import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import "controls" as C

// Side panel with a title and a list of actions, in the quick-menu style. Used for
// "Console options" and "Add / manage" on the consoles screen (instead of popup menus,
// which do not render reliably in chiaki's offscreen window).
//
// actions: [{ text, detail, icon, run: function, keepOpen, toggle, isOn: function,
//             isEnabled: function, danger }]. Functions are called inside bindings, so the
// rows follow live state (e.g. discovery on/off) without rebuilding the list.
FocusScope {
    id: panel
    Material.theme: Material.Dark
    property bool spatialNavScope: true
    property string title
    property string subtitle
    property string info          // optional details block under the actions
    property var actions: []
    signal closeRequested()

    function focusFirst() {
        for (let i = 0; i < rows.count; ++i) {
            const row = rows.itemAt(i);
            if (row && row.enabled) { row.forceActiveFocus(Qt.TabFocusReason); return; }
        }
        panel.forceActiveFocus(Qt.TabFocusReason);
    }

    Keys.onEscapePressed: closeRequested()
    Keys.onBackPressed: closeRequested()
    Keys.onNoPressed: closeRequested()
    Keys.onYesPressed: closeRequested()

    Rectangle {
        anchors.fill: parent
        color: "#0c0e13"
        Rectangle { width: 1; height: parent.height; color: "#232833" }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 22; anchors.rightMargin: 22; anchors.topMargin: 22
        spacing: 12

        RowLayout {
            spacing: 14
            Layout.bottomMargin: 6
            RoundButton {
                Layout.preferredWidth: 46; Layout.preferredHeight: 46
                focusPolicy: Qt.NoFocus
                icon.source: "qrc:/icons/portal/back.svg"
                icon.width: 22; icon.height: 22
                icon.color: "#ffffff"
                background: Rectangle { radius: 23; color: "#232a36" }
                onClicked: panel.closeRequested()
                Accessible.name: qsTr("Back")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { Layout.fillWidth: true; text: panel.title; font.pixelSize: 26; color: "#ffffff"; elide: Text.ElideRight }
                Label { Layout.fillWidth: true; visible: text; text: panel.subtitle; font.pixelSize: 14; color: "#a9a5ba"; elide: Text.ElideRight }
            }
        }

        Repeater {
            id: rows
            model: panel.actions
            C.Button {
                id: row
                required property var modelData
                required property int index
                readonly property bool on: modelData.isOn ? modelData.isOn() : false
                enabled: modelData.isEnabled ? modelData.isEnabled() : true
                visible: modelData.isVisible ? modelData.isVisible() : true
                firstInFocusChain: index === 0
                lastInFocusChain: index === rows.count - 1
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(68, rowText.implicitHeight + 24)
                leftPadding: 20; rightPadding: 20
                text: modelData.text
                background: Rectangle {
                    radius: 16
                    color: row.activeFocus ? "#24344c" : row.hovered ? "#222833" : "#1a1e27"
                    border.width: row.activeFocus ? 2 : 0
                    border.color: "#e3efff"
                    opacity: row.enabled ? 1 : 0.45
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                contentItem: RowLayout {
                    spacing: 18
                    opacity: row.enabled ? 1 : 0.6
                    Image {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30
                        sourceSize: Qt.size(60, 60)
                        source: "qrc:/icons/portal/" + (row.modelData.icon || "chevron") + ".svg"
                    }
                    Column {
                        id: rowText
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            width: parent.width
                            text: row.modelData.text
                            color: row.modelData.danger ? "#ffb4ab" : "#ffffff"
                            font.pixelSize: 17; elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: text
                            text: row.modelData.detail || ""
                            color: "#a9a5ba"; font.pixelSize: 14; wrapMode: Text.WordWrap
                        }
                    }
                    Rectangle {
                        visible: !!row.modelData.toggle
                        Layout.preferredWidth: 52; Layout.preferredHeight: 30
                        radius: 15
                        color: row.on ? "#4c9dff" : "#444b58"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Rectangle {
                            width: 24; height: 24; radius: 12
                            y: 3; x: row.on ? parent.width - width - 3 : 3
                            color: row.on ? "#ffffff" : "#d6d4de"
                            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        }
                    }
                }
                onClicked: {
                    const action = row.modelData;
                    if (!action.keepOpen && !action.toggle)
                        panel.closeRequested();
                    if (action.run)
                        action.run();
                }
            }
        }

        Rectangle {
            visible: !!panel.info
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: infoText.implicitHeight + 24
            radius: 14
            color: "#141821"
            border.width: 1; border.color: "#232833"
            Label {
                id: infoText
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: 16; anchors.rightMargin: 16
                text: panel.info
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                font.pixelSize: 14
                color: "#c9c5d8"
                lineHeight: 1.2
            }
        }
        Item { Layout.fillHeight: true }
    }
}
