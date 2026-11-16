import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

Item {
    id: dialog
    property alias header: headerLabel.text
    property alias title: titleLabel.text
    property alias buttonText: okButton.text
    property alias buttonEnabled: okButton.enabled
    property alias buttonVisible: okButton.visible
    property Item restoreFocusItem
    // false: the page draws its own Portal-style header (PortalSettings), so hide the toolbar.
    property bool chrome: true
    default property Item mainItem: null

    signal accepted()
    signal rejected()

    function close() {
        root.closeDialog();
    }

    Keys.onEscapePressed: close()

    Keys.onMenuPressed: {
        if (okButton.visible && okButton.enabled)
            okButton.clicked()
    }

    StackView.onDeactivating: {
        restoreFocusItem = Window.window.activeFocusItem;
    }

    StackView.onActivated: {
        if (!restoreFocusItem) {
            let item = mainItem.nextItemInFocusChain();
            if (item)
                item.forceActiveFocus(Qt.TabFocusReason);
        } else {
            restoreFocusItem.forceActiveFocus(Qt.TabFocusReason);
            restoreFocusItem = null;
        }
    }

    onMainItemChanged: {
        if (mainItem) {
            mainItem.parent = contentItem;
            mainItem.anchors.fill = contentItem;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#101116"
        z: -1
    }

    Item {
        id: toolBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: dialog.chrome
        height: !dialog.chrome ? 0 : headerLabel.text ? 112 : 88

        RoundButton {
            id: backButton
            anchors.left: parent.left
            anchors.leftMargin: dialog.width < 800 ? 20 : 36
            anchors.top: parent.top
            anchors.topMargin: 20
            width: 48
            height: 48
            focusPolicy: Qt.NoFocus
            icon.source: "qrc:/icons/portal/back.svg"
            icon.width: 22; icon.height: 22; icon.color: "#ffffff"
            background: Rectangle { radius: 24; color: backButton.hovered ? "#2d3544" : "#232a36" }
            onClicked: { dialog.rejected(); dialog.close(); }
            Accessible.name: qsTr("Back")
        }
        Label {
            id: titleLabel
            anchors.left: backButton.right
            anchors.leftMargin: 16
            anchors.right: okButton.visible ? okButton.left : parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: backButton.verticalCenter
            font.pixelSize: dialog.width < 800 ? 24 : 28
            elide: Text.ElideRight
            color: "#ffffff"
        }
        Button {
            id: okButton
            anchors.right: parent.right
            anchors.rightMargin: dialog.width < 800 ? 20 : 36
            anchors.verticalCenter: backButton.verticalCenter
            width: Math.max(140, implicitContentWidth + 48)
            height: 52
            focusPolicy: Qt.NoFocus
            background: Rectangle {
                radius: 26
                color: okButton.enabled ? "#ffffff" : "#292b35"
            }
            // The Options / Menu button triggers this action (Keys.onMenuPressed above).
            contentItem: Row {
                spacing: 10
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; sourceSize: Qt.size(48, 48)
                    source: "qrc:/icons/portal/options-badge-dark.svg"
                    opacity: okButton.enabled ? 1 : 0.4
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: okButton.text
                    font.pixelSize: 17
                    color: okButton.enabled ? "#101116" : "#777b88"
                }
            }
            onClicked: dialog.accepted()
        }
        Label {
            id: headerLabel
            anchors.left: backButton.left
            anchors.right: parent.right
            anchors.rightMargin: 36
            anchors.top: backButton.bottom
            anchors.topMargin: 12
            color: "#a9a5ba"
            font.pixelSize: 15
            elide: Text.ElideRight
        }
    }

    Item {
        id: contentItem
        anchors.top: toolBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: !dialog.chrome ? 0 : dialog.width < 800 ? 20 : 36
        anchors.rightMargin: !dialog.chrome ? 0 : dialog.width < 800 ? 20 : 36
        anchors.bottomMargin: !dialog.chrome ? 0 : 24
    }
}