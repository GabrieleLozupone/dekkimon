import QtQuick
import QtQuick.Controls

Item {
    id: navigation
    property int currentIndex: 0
    property bool compact: false
    readonly property var categories: [
        qsTr("General"), qsTr("Video"), qsTr("Streaming"), qsTr("Audio & Wi-Fi"),
        qsTr("Consoles"), qsTr("Keyboard"), qsTr("Controllers"),
        qsTr("Remote access"), qsTr("Profiles & data")
    ]
    readonly property var descriptions: [
        qsTr("Choose how Remote Play starts and ends."),
        qsTr("Set up decoding and video presentation."),
        qsTr("Choose stream quality for your console and connection."),
        qsTr("Manage sound, microphone and wireless behavior."),
        qsTr("Pair and manage your PlayStation consoles."),
        qsTr("Customize keyboard shortcuts."),
        qsTr("Configure buttons, motion and feedback."),
        qsTr("Manage your PlayStation Network connection."),
        qsTr("Save, switch and manage your configuration.")
    ]
    function decrementCurrentIndex() { currentIndex = (currentIndex + categories.length - 1) % categories.length; }
    function incrementCurrentIndex() { currentIndex = (currentIndex + 1) % categories.length; }
    ListView {
        id: categoryList
        anchors.fill: parent
        clip: true
        orientation: navigation.compact ? ListView.Horizontal : ListView.Vertical
        spacing: 4
        model: navigation.categories
        currentIndex: navigation.currentIndex
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        ScrollBar.vertical: ScrollBar { visible: !navigation.compact }
        ScrollBar.horizontal: ScrollBar { visible: navigation.compact }
        delegate: Button {
            id: category
            required property string modelData
            required property int index
            width: navigation.compact ? Math.max(110, implicitContentWidth + 32) : categoryList.width
            height: 48
            focusPolicy: Qt.NoFocus
            text: modelData
            onClicked: navigation.currentIndex = index
            Accessible.name: text
            Accessible.description: navigation.currentIndex === index ? qsTr("Selected category") : ""
            background: Rectangle {
                radius: 8
                color: navigation.currentIndex === category.index ? "#f4f4f6" : category.hovered ? "#24262e" : "transparent"
            }
            contentItem: Text {
                text: category.text
                font.pixelSize: 16
                color: navigation.currentIndex === category.index ? "#101116" : "#c4c5cd"
                verticalAlignment: Text.AlignVCenter
                leftPadding: 16
            }
        }
    }
}