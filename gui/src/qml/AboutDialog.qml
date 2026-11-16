import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import "controls" as C

// About card in the Portal pop-up style: icon, name, version, origin and licence.
Dialog {
    id: dialog
    property Item restoreFocusItem
    property bool spatialNavScope: true
    parent: Overlay.overlay
    width: Math.min(root.width - 80, 820)
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    modal: true
    padding: 36
    Overlay.modal: Rectangle { color: "#b3050810" }
    background: Rectangle {
        radius: 26
        color: "#161a22"
        border.width: 1
        border.color: "#2b3140"
    }
    onOpened: closeButton.forceActiveFocus(Qt.TabFocusReason)
    onClosed: if (restoreFocusItem) restoreFocusItem.forceActiveFocus(Qt.TabFocusReason)

    ColumnLayout {
        width: parent.width
        spacing: 28

        RowLayout {
            Layout.fillWidth: true
            spacing: 32

            Image {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 168
                Layout.preferredHeight: 168
                sourceSize: Qt.size(336, 336)
                smooth: true
                mipmap: true
                source: "qrc:/icons/dekkimon-icon.png"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                RowLayout {
                    spacing: 14
                    Label { text: "Dekkimon"; font.pixelSize: 36; font.weight: Font.DemiBold; color: "#ffffff" }
                    Label { text: "デッキ門"; font.pixelSize: 20; color: "#8fc3ff"; Layout.alignment: Qt.AlignBaseline }
                }
                Label {
                    text: qsTr("Version %1").arg(Qt.application.version)
                    font.pixelSize: 15
                    color: "#a9a5ba"
                }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    wrapMode: Text.WordWrap
                    font.pixelSize: 17
                    lineHeight: 1.15
                    color: "#e4e1ee"
                    text: qsTr("Stream your PlayStation console to your Steam Deck.")
                }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    font.pixelSize: 15
                    lineHeight: 1.2
                    color: "#c9c5d8"
                    text: qsTr("Based on <b>chiaki-ng</b> by Street Pea, a fork of <b>Chiaki</b> by Florian Markl.")
                }
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            lineHeight: 1.2
            color: "#8e8aa0"
            text: qsTr("Free software under the GNU Affero General Public License version 3, without any warranty. "
                     + "Not affiliated with Sony Interactive Entertainment or Valve. "
                     + "PlayStation, PS5 and Steam Deck are trademarks of their respective owners.")
        }

        C.DialogButton {
            id: closeButton
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Close")
            glyph: "moon"
            onClicked: dialog.close()
            Keys.onEscapePressed: dialog.close()
            Keys.onNoPressed: dialog.close()
        }
    }
}
