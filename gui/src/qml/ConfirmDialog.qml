import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import "controls" as C

// Yes / No pop-up in the Portal card style. ✕ activates the focused action, ○ answers No.
Dialog {
    id: dialog
    property alias text: label.text
    property var callback
    property var rejectCallback
    property bool newDialogOpen: false
    property Item restoreFocusItem
    property bool spatialNavScope: true
    parent: Overlay.overlay
    width: Math.min(root.width - 80, 640)
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    modal: true
    padding: 32
    topPadding: 8
    Overlay.modal: Rectangle { color: "#b3050810" }
    background: Rectangle {
        radius: 26
        color: "#161a22"
        border.width: 1
        border.color: "#2b3140"
    }
    header: Label {
        text: dialog.title
        topPadding: 32; leftPadding: 32; rightPadding: 32; bottomPadding: 6
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.pixelSize: 26
        color: "#ffffff"
    }
    onOpened: yesButton.forceActiveFocus(Qt.TabFocusReason)
    onAccepted: {
        newDialogOpen = true;
        restoreFocus();
        callback();
    }
    onClosed: if(!newDialogOpen) { restoreFocus() }

    onRejected: {
        if(rejectCallback)
        {
            newDialogOpen = true;
            restoreFocus();
            rejectCallback();
        }
    }

    function restoreFocus() {
        if (restoreFocusItem)
            restoreFocusItem.forceActiveFocus(Qt.TabFocusReason);
    }

    ColumnLayout {
        width: parent.width
        spacing: 26
        Keys.onEscapePressed: dialog.reject()
        Keys.onNoPressed: dialog.reject()

        Label {
            id: label
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 17
            lineHeight: 1.15
            color: "#c9c5d8"
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            C.DialogButton {
                id: yesButton
                text: qsTr("Yes")
                glyph: "cross"
                onClicked: dialog.accept()
            }
            C.DialogButton {
                text: qsTr("No")
                glyph: "moon"
                onClicked: dialog.reject()
            }
        }
    }
}
