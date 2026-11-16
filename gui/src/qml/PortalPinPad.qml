import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

FocusScope {
    id: pad
    property string text: ""
    readonly property bool acceptableInput: /^[0-9]{4}$/.test(text)
    property int selectedKey: 0
    signal accepted()
    signal cancelled()
    implicitWidth: 460
    implicitHeight: 360
    function activate(index) {
        if(index === 9) text = text.slice(0, -1);
        else if(index === 11) { if(acceptableInput) accepted(); }
        else if(text.length < 4) text += index === 10 ? "0" : String(index + 1);
    }
    Keys.onLeftPressed: selectedKey = (selectedKey + 11) % 12
    Keys.onRightPressed: selectedKey = (selectedKey + 1) % 12
    Keys.onUpPressed: selectedKey = (selectedKey + 9) % 12
    Keys.onDownPressed: selectedKey = (selectedKey + 3) % 12
    Keys.onReturnPressed: activate(selectedKey)
    Keys.onEscapePressed: { if(text.length) text = text.slice(0,-1); else cancelled(); }
    Keys.onNoPressed: text = text.slice(0,-1)
    Keys.onPressed: event => {
        if(event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            if(text.length < 4) text += String(event.key - Qt.Key_0);
            event.accepted = true;
        } else if(event.key === Qt.Key_Backspace) {
            text = text.slice(0,-1); event.accepted = true;
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 16
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 56; height: 64; radius: 14
                    color: "#1a1e27"
                    border.width: index === pad.text.length ? 2 : 0
                    border.color: "#e3efff"
                    Text { anchors.centerIn: parent; text: index < pad.text.length ? "•" : ""; color: "white"; font.pixelSize: 30 }
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rowSpacing: 8; columnSpacing: 8
            Repeater {
                model: 12
                Button {
                    id: digit
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1   // equal columns regardless of label width
                    Layout.minimumHeight: 38
                    focusPolicy: Qt.NoFocus
                    text: index === 9 ? qsTr("Delete") : index === 10 ? "0" : index === 11 ? qsTr("Continue") : String(index+1)
                    enabled: index !== 11 || pad.acceptableInput
                    background: Rectangle {
                        radius: 16
                        color: digit.index === pad.selectedKey ? "#24344c" : digit.hovered ? "#222833" : "#1a1e27"
                        border.width: digit.index === pad.selectedKey ? 2 : 0
                        border.color: "#e3efff"
                        opacity: digit.enabled ? 1 : 0.45
                    }
                    contentItem: Text {
                        text: digit.text; color: digit.enabled ? "#ffffff" : "#888394"
                        font.pixelSize: digit.index === 9 || digit.index === 11 ? 16 : 26
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: { pad.selectedKey = index; pad.forceActiveFocus(); pad.activate(index); }
                }
            }
        }
    }
}