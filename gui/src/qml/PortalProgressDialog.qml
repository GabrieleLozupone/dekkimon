import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import "controls" as C

// Portal-style card for a running task with a log (console registration, Steam shortcut).
// While `busy`, the single button reads "Cancel"; when done it reads "Close". Up/Down scroll
// the log; ✕ or ○ press the button.
Dialog {
    id: dialog
    property string log: ""
    property bool busy: true
    property string doneText: qsTr("Close")
    property bool spatialNavScope: true
    signal finished()
    parent: Overlay.overlay
    width: Math.min(root.width - 80, 720)
    height: Math.min(root.height - 80, 560)
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    modal: true
    closePolicy: Popup.NoAutoClose
    padding: 32
    topPadding: 8
    Overlay.modal: Rectangle { color: "#b3050810" }
    background: Rectangle {
        radius: 26
        color: "#161a22"
        border.width: 1
        border.color: "#2b3140"
    }
    header: RowLayout {
        spacing: 14
        Item { Layout.preferredWidth: 18 }
        BusyIndicator {
            Layout.topMargin: 24
            Layout.preferredWidth: 34; Layout.preferredHeight: 34
            running: dialog.busy
            visible: dialog.busy
            Material.accent: "#8fb8ff"
        }
        Label {
            Layout.fillWidth: true
            Layout.topMargin: 28; Layout.bottomMargin: 6; Layout.rightMargin: 32
            text: dialog.title
            elide: Text.ElideRight
            font.pixelSize: 26
            color: "#ffffff"
        }
    }
    onOpened: button.forceActiveFocus(Qt.TabFocusReason)
    onClosed: finished()

    function append(line) { log += (log ? "\n" : "") + line; }

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: "#0e1117"
            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 18
                clip: true
                contentWidth: width
                contentHeight: logLabel.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: flick.contentHeight > flick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
                // Follow the end of the log while it grows.
                onContentHeightChanged: if (contentHeight > height) contentY = contentHeight - height
                Label {
                    id: logLabel
                    width: flick.width - 14
                    text: dialog.log
                    wrapMode: Text.Wrap
                    font.pixelSize: 15
                    lineHeight: 1.2
                    color: "#c9c5d8"
                }
            }
        }

        C.DialogButton {
            id: button
            Layout.alignment: Qt.AlignHCenter
            text: dialog.busy ? qsTr("Cancel") : dialog.doneText
            glyph: "moon"
            onClicked: dialog.close()
            Keys.onUpPressed: event => { flick.contentY = Math.max(0, flick.contentY - 80); event.accepted = true; }
            Keys.onDownPressed: event => { flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + 80)); event.accepted = true; }
            Keys.onEscapePressed: dialog.close()
            Keys.onNoPressed: dialog.close()
        }
    }
}
