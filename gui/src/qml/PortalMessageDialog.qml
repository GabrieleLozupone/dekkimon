import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import "controls" as C

// Portal-style message card with one button. With `captureKeys`, the next key released is
// reported through keyCaptured() instead of operating the button (key-mapping capture); the
// button then only responds to touch/mouse. Focus returns to where it was when closed.
Dialog {
    id: dialog
    property alias text: label.text
    property string buttonText: qsTr("Close")
    property bool captureKeys: false
    property Item restoreFocusItem
    property bool spatialNavScope: true
    signal keyCaptured(int key)
    parent: Overlay.overlay
    width: Math.min(root.width - 80, 600)
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
    onAboutToShow: if (!restoreFocusItem && Window.window) restoreFocusItem = Window.window.activeFocusItem
    onOpened: (captureKeys ? capture : button).forceActiveFocus(Qt.TabFocusReason)
    onClosed: {
        if (restoreFocusItem)
            restoreFocusItem.forceActiveFocus(Qt.TabFocusReason);
        restoreFocusItem = null;
    }

    ColumnLayout {
        width: parent.width
        spacing: 26

        Label {
            id: label
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: 17
            lineHeight: 1.15
            color: "#c9c5d8"
        }

        // Key capture target (only focused in captureKeys mode).
        Item {
            id: capture
            Layout.preferredHeight: 0
            Keys.onReleased: event => {
                if (event.isAutoRepeat) return;
                event.accepted = true;
                dialog.keyCaptured(event.key);
            }
            Keys.onPressed: event => event.accepted = true
        }

        C.DialogButton {
            id: button
            Layout.alignment: Qt.AlignHCenter
            text: dialog.buttonText
            glyph: "moon"
            onClicked: dialog.close()
            Keys.onEscapePressed: dialog.close()
            Keys.onNoPressed: dialog.close()
        }
    }
}
