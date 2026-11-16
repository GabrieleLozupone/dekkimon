import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import "controls" as C

import org.streetpea.chiaking

// Yes / No / Remind me later pop-up in the Portal card style (e.g. "Remote Play via PSN").
Dialog {
    id: dialog
    property alias text: label.text
    property var remotePlay
    property var callback
    property bool newDialogOpen: false
    property Item restoreFocusItem
    property bool spatialNavScope: true
    parent: Overlay.overlay
    width: Math.min(root.width - 80, 680)
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
    onRejected: {
        if(dialog.remotePlay)
            Chiaki.settings.remotePlayAsk = false;
        else
            Chiaki.settings.addSteamShortcutAsk = false;
    }
    onClosed: {
        if(newDialogOpen)
            return;
        restoreFocus();
        if(!remotePlay && Chiaki.settings.remotePlayAsk)
        {
            if(!Chiaki.settings.psnRefreshToken || !Chiaki.settings.psnAuthToken || !Chiaki.settings.psnAuthTokenExpiry || !Chiaki.settings.psnAccountId)
                root.showRemindDialog(qsTr("Remote Play via PSN"), qsTr("Sign in to PlayStation Network to register consoles automatically and to play away from home without port forwarding.") + "\n\n" + qsTr("You can do this later in Settings › Remote access."), true, () => root.showPSNTokenDialog(false));
            else
                Chiaki.settings.remotePlayAsk = false;
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
        Keys.onYesPressed: dialog.close()

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
            spacing: 14
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
            C.DialogButton {
                text: qsTr("Remind me later")
                glyph: "pyramid"
                onClicked: dialog.close()
            }
        }
    }
}
