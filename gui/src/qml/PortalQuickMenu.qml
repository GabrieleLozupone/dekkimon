import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import org.streetpea.chiaking
import "controls" as C
import "controls/ConnectionText.js" as Conn

// Shared quick-settings sidebar (home drawer and in-stream menu).
// Page 1: two large tiles, connection card, volume/microphone, navigation rows.
// Pushed pages: Connection details, Picture & HDR, Leave Remote Play, option lists.
FocusScope {
    id: panel
    Material.theme: Material.Dark
    Material.accent: "#cfe3ff"
    Material.foreground: "#f4f2fa"
    // Arrow-key navigation stays inside the panel (controls/SpatialNav.js).
    property bool spatialNavScope: true
    property bool streaming: false
    property alias initialFocusItem: resume
    property string clockText: Qt.formatTime(new Date(), "h:mm AP")
    signal closeRequested()
    // Kept for callers without a session (returns to the home screen).
    signal disconnectRequested()
    // Leave Remote Play; sleep = put the console in rest mode.
    signal stopRequested(bool sleep)
    signal settingsRequested()
    signal streamSettingsRequested()
    signal displaySettingsRequested()
    signal placeboSettingsRequested()
    signal consolesRequested()

    readonly property var fitModes: [
        { label: qsTr("Fit"), icon: "fit", detail: qsTr("Keep the console's 16:9 picture. Thin bars on 16:10 screens.") },
        { label: qsTr("Stretch"), icon: "fit", detail: qsTr("Fill the whole screen. Slightly distorts the picture.") },
        { label: qsTr("Zoom"), icon: "fit", detail: qsTr("Fill the whole screen by cropping the edges.") }
    ]
    readonly property var qualityModes: [
        { label: qsTr("Fast"), icon: "quality", detail: qsTr("Lowest GPU load and battery use.") },
        { label: qsTr("Default"), icon: "quality", detail: qsTr("Balanced scaling.") },
        { label: qsTr("High quality"), icon: "quality", detail: qsTr("Sharper scaling. Recommended on Steam Deck OLED.") },
        { label: qsTr("HQ + spatial"), icon: "quality", detail: qsTr("Adds spatial upscaling.") },
        { label: qsTr("HQ + advanced spatial"), icon: "quality", detail: qsTr("Best upscaling, highest GPU load.") },
        { label: qsTr("Custom"), icon: "picture", detail: qsTr("Uses your Picture settings.") }
    ]
    function presetList() {
        return [ChiakiWindow.VideoPreset.Fast, ChiakiWindow.VideoPreset.Default,
                ChiakiWindow.VideoPreset.HighQuality, ChiakiWindow.VideoPreset.HighQualitySpatial,
                ChiakiWindow.VideoPreset.HighQualityAdvancedSpatial, ChiakiWindow.VideoPreset.Custom];
    }
    function fitList() {
        return [ChiakiWindow.VideoMode.Normal, ChiakiWindow.VideoMode.Stretch, ChiakiWindow.VideoMode.Zoom];
    }
    function openFitPage() {
        pages.push(optionPage, {
            title: qsTr("Screen fit"),
            options: fitModes,
            selected: fitList().indexOf(Chiaki.window.videoMode),
            note: qsTr("Changes apply immediately."),
            apply: index => { Chiaki.window.videoMode = fitList()[index]; }
        });
    }
    function openConnectionPage() {
        if (pages.depth > 1) pages.pop(null, StackView.Immediate);
        pages.push(connectionPage, { streaming: panel.streaming });
    }
    function openPicturePage() {
        pages.push(picturePage);
    }
    // Disconnect: follow "When I disconnect" in Settings; only "Ask every time" shows the choice.
    function leave() {
        const action = Chiaki.settings ? Chiaki.settings.disconnectAction : 2;
        if (!Chiaki.session) { panel.disconnectRequested(); return; }
        if (action === 0) panel.stopRequested(false);
        else if (action === 1) panel.stopRequested(true);
        else pages.push(leavePage);
    }
    function openQualityPage() {
        pages.push(optionPage, {
            title: qsTr("Rendering quality"),
            options: qualityModes,
            selected: presetList().indexOf(Chiaki.window.videoPreset),
            note: qsTr("Controls how the stream is scaled and filtered on this device. It does not change the stream's bitrate."),
            apply: index => {
                Chiaki.window.videoPreset = presetList()[index];
                Chiaki.settings.videoPreset = presetList()[index];
            }
        });
    }

    Timer { interval: 15000; running: panel.visible; repeat: true; triggeredOnStart: true
        onTriggered: panel.clockText = Qt.formatTime(new Date(), "h:mm AP") }
    // Ignore close/activate input right after the panel appears: a duplicated controller
    // press (or key repeat) would otherwise close it as soon as it opens.
    property bool armed: false
    function requestClose(source) {
        if (!armed) { console.info("quick menu: ignored early " + source); return; }
        closeRequested();
    }
    Timer { id: armTimer; interval: 350; onTriggered: panel.armed = true }
    Component.onCompleted: if (visible) armTimer.restart()
    onVisibleChanged: {
        armed = false;
        if (visible) armTimer.restart();
        else if (pages.depth > 1) pages.pop(null, StackView.Immediate);
    }
    Keys.onEscapePressed: requestClose("back")
    Keys.onMenuPressed: requestClose("menu")

    Rectangle {
        anchors.fill: parent
        color: "#0c0e13"
        Rectangle { width: 1; height: parent.height; color: "#232833" }
    }

    // Header: clock and link status, as on the handheld.
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: 26; anchors.rightMargin: 26
        height: 72
        Label { anchors.verticalCenter: parent.verticalCenter; text: panel.clockText; font.pixelSize: 24; color: "#ffffff" }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            visible: Conn.shown(Chiaki.wifi)
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Conn.qualityLabel(Chiaki.wifi)
                color: "#c9c5d8"; font.pixelSize: 16
            }
            C.SignalBars {
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 18
                level: Conn.bars(Chiaki.wifi)
                wired: !!Chiaki.wifi && Chiaki.wifi.kind === "wired"
            }
        }
    }

    // ---- building blocks -------------------------------------------------------------
    component Tile: C.Button {
        id: tile
        property string iconName
        property string detail
        Layout.fillWidth: true
        Layout.preferredHeight: 156
        background: Rectangle {
            radius: 18
            color: tile.activeFocus ? "#24344c" : tile.hovered ? "#222833" : "#1a1e27"
            border.width: tile.activeFocus ? 2 : 0
            border.color: "#e3efff"
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                visible: tile.activeFocus
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00ffffff" }
                    GradientStop { position: 1; color: "#14569dff" }
                }
            }
        }
        contentItem: Item {
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.12
                width: 52; height: 52; sourceSize: Qt.size(104, 104)
                source: "qrc:/icons/portal/" + tile.iconName + ".svg"
            }
            Column {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                width: parent.width
                spacing: 2
                Text {
                    width: parent.width
                    text: tile.text; color: "#ffffff"; font.pixelSize: 17
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    visible: text
                    text: tile.detail; color: "#a9a5ba"; font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                }
            }
        }
    }
    component NavRow: C.Button {
        id: row
        property string iconName
        property string value
        property bool toggle: false
        property bool on: false
        Layout.fillWidth: true
        Layout.preferredHeight: 72
        leftPadding: 22; rightPadding: 20
        background: Rectangle {
            radius: 16
            color: row.activeFocus ? "#24344c" : row.hovered ? "#222833" : "#1a1e27"
            border.width: row.activeFocus ? 2 : 0
            border.color: "#e3efff"
            opacity: row.enabled ? 1 : 0.5
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        contentItem: RowLayout {
            spacing: 18
            Image {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                sourceSize: Qt.size(60, 60)
                source: "qrc:/icons/portal/" + row.iconName + ".svg"
            }
            Text {
                Layout.fillWidth: true
                text: row.text; color: "#ffffff"; font.pixelSize: 17
                elide: Text.ElideRight
            }
            Text {
                visible: !row.toggle && text
                text: row.value; color: "#a9a5ba"; font.pixelSize: 15
            }
            Image {
                visible: !row.toggle
                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                sourceSize: Qt.size(36, 36)
                source: "qrc:/icons/portal/chevron.svg"
                opacity: 0.6
            }
            Rectangle {
                // Switch, drawn to match the handheld's pill toggle.
                visible: row.toggle
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
    }

    StackView {
        id: pages
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom }
        clip: true
        initialItem: mainPage
        pushEnter: Transition { NumberAnimation { property: "x"; from: pages.width * 0.3; to: 0; duration: 200; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } }
        pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
        popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } }
        popExit: Transition { NumberAnimation { property: "x"; from: 0; to: pages.width * 0.3; duration: 180; easing.type: Easing.InCubic }
                              NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 160 } }
        onDepthChanged: if (depth === 1 && panel.visible) Qt.callLater(() => (lastMainFocus || resume).forceActiveFocus(Qt.TabFocusReason))
        property Item lastMainFocus: null
    }

    FocusScope {
        id: mainPage
        Flickable {
            id: scroll
            anchors.fill: parent
            anchors.leftMargin: 22; anchors.rightMargin: 22
            contentHeight: controls.height + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            ColumnLayout {
                id: controls
                width: parent.width
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Tile {
                        id: resume
                        text: panel.streaming ? qsTr("Return to game") : qsTr("Back to home")
                        iconName: "controller"
                        firstInFocusChain: true
                        onClicked: panel.requestClose("return tile")
                    }
                    Tile {
                        id: secondaryAction
                        text: panel.streaming ? qsTr("Disconnect") : qsTr("Consoles")
                        detail: panel.streaming ? qsTr("Leave Remote Play") : qsTr("Other connections")
                        iconName: panel.streaming ? "disconnect" : "console"
                        onClicked: { if (panel.streaming) panel.leave(); else panel.consolesRequested(); }
                    }
                }
                C.Button {
                    id: connectionCard
                    visible: Conn.shown(Chiaki.wifi)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    leftPadding: 22; rightPadding: 20
                    Accessible.name: qsTr("Connection")
                    background: Rectangle {
                        radius: 16
                        color: connectionCard.activeFocus ? "#24344c" : connectionCard.hovered ? "#222833" : "#1a1e27"
                        border.width: connectionCard.activeFocus ? 2 : 0
                        border.color: "#e3efff"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    contentItem: RowLayout {
                        spacing: 18
                        C.SignalBars {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 22
                            level: Conn.bars(Chiaki.wifi)
                            wired: !!Chiaki.wifi && Chiaki.wifi.kind === "wired"
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                width: parent.width
                                text: Conn.summary(Chiaki.wifi)
                                color: "#ffffff"; font.pixelSize: 17; elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: panel.streaming && Chiaki.session
                                    ? qsTr("Stream %1 Mbps · %2% loss").arg(Number(Chiaki.session.measuredBitrate || 0).toFixed(1))
                                        .arg((Number(Chiaki.session.averagePacketLoss || 0) * 100).toFixed(1))
                                    : (Conn.band(Chiaki.wifi) || qsTr("Connection details"))
                                color: "#a9a5ba"; font.pixelSize: 14; elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            // Amber dot when there is advice on the Connection page.
                            visible: Conn.tips(Chiaki.wifi, Chiaki.settings).length > 0
                            Layout.preferredWidth: 10; Layout.preferredHeight: 10
                            radius: 5; color: "#f0c585"
                        }
                        Image {
                            Layout.preferredWidth: 18; Layout.preferredHeight: 18
                            sourceSize: Qt.size(36, 36)
                            source: "qrc:/icons/portal/chevron.svg"
                            opacity: 0.6
                        }
                    }
                    onClicked: { pages.lastMainFocus = connectionCard; panel.openConnectionPage(); }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: 16
                    color: volume.activeFocus ? "#24344c" : "#1a1e27"
                    border.width: volume.activeFocus ? 2 : 0
                    border.color: "#e3efff"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 22; anchors.rightMargin: 14
                        spacing: 10
                        Image {
                            Layout.preferredWidth: 30; Layout.preferredHeight: 30
                            sourceSize: Qt.size(60, 60)
                            source: "qrc:/icons/portal/volume.svg"
                        }
                        C.Slider {
                            id: volume
                            Layout.fillWidth: true
                            from: 0; to: 128; stepSize: 1
                            value: Chiaki.settings.audioVolume
                            onMoved: Chiaki.settings.audioVolume = value
                            Accessible.name: qsTr("Stream volume")
                            Material.accent: "#ffffff"
                        }
                    }
                }
                NavRow {
                    id: microphone
                    visible: panel.streaming
                    enabled: !!Chiaki.session && Chiaki.session.connected
                    text: qsTr("Microphone")
                    iconName: on ? "mic" : "mic-off"
                    toggle: true
                    on: !!Chiaki.session && !Chiaki.session.muted
                    onClicked: if (Chiaki.session) Chiaki.session.muted = !Chiaki.session.muted
                }
                NavRow {
                    id: pictureRow
                    visible: panel.streaming
                    text: qsTr("Picture & HDR")
                    iconName: "picture"
                    value: panel.streaming ? (panel.fitModes[panel.fitList().indexOf(Chiaki.window.videoMode)] || {label: ""}).label : ""
                    onClicked: { pages.lastMainFocus = pictureRow; panel.openPicturePage(); }
                }
                NavRow {
                    visible: panel.streaming
                    text: qsTr("Performance overlay")
                    iconName: "stats"
                    toggle: true
                    on: !!Chiaki.settings.showStreamStats
                    lastInFocusChain: panel.streaming
                    onClicked: Chiaki.settings.showStreamStats = !Chiaki.settings.showStreamStats
                }
                NavRow {
                    visible: !panel.streaming
                    text: qsTr("Stream quality")
                    iconName: "quality"
                    onClicked: panel.streamSettingsRequested()
                }
                NavRow {
                    text: qsTr("Settings")
                    iconName: "settings"
                    visible: !panel.streaming
                    lastInFocusChain: !panel.streaming
                    onClicked: panel.settingsRequested()
                }
            }
            Connections {
                target: panel.Window.window
                function onActiveFocusItemChanged() {
                    const item = panel.Window.window ? panel.Window.window.activeFocusItem : null;
                    if (!item || !panel.visible) return;
                    let ancestor = item;
                    while (ancestor && ancestor !== controls) ancestor = ancestor.parent;
                    if (!ancestor) return;
                    const top = item.mapToItem(controls, 0, 0).y;
                    if (top < scroll.contentY) scroll.contentY = Math.max(0, top - 12);
                    else if (top + item.height > scroll.contentY + scroll.height)
                        scroll.contentY = top + item.height - scroll.height + 12;
                }
            }
        }
    }

    component PageHeader: RowLayout {
        id: pageHeader
        property string title
        signal back()
        spacing: 14
        Layout.bottomMargin: 10
        RoundButton {
            Layout.preferredWidth: 46; Layout.preferredHeight: 46
            focusPolicy: Qt.NoFocus
            icon.source: "qrc:/icons/portal/back.svg"
            icon.width: 22; icon.height: 22
            icon.color: "#ffffff"
            background: Rectangle { radius: 23; color: "#232a36" }
            onClicked: pageHeader.back()
            Accessible.name: qsTr("Back")
        }
        Label { text: pageHeader.title; font.pixelSize: 26; color: "#ffffff" }
    }

    // Large choice row used by the Leave page.
    component BigChoice: C.Button {
        id: choice
        property string iconName
        property string detail
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(84, choiceText.implicitHeight + 28)
        leftPadding: 20; rightPadding: 20
        background: Rectangle {
            radius: 16
            color: choice.activeFocus ? "#24344c" : choice.hovered ? "#222833" : "#1a1e27"
            border.width: choice.activeFocus ? 2 : 0
            border.color: "#e3efff"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        contentItem: RowLayout {
            spacing: 18
            Image {
                Layout.preferredWidth: 34; Layout.preferredHeight: 34
                sourceSize: Qt.size(68, 68)
                source: "qrc:/icons/portal/" + choice.iconName + ".svg"
            }
            Column {
                id: choiceText
                Layout.fillWidth: true
                spacing: 4
                Text { width: parent.width; text: choice.text; color: "#ffffff"; font.pixelSize: 18; elide: Text.ElideRight }
                Text { width: parent.width; text: choice.detail; color: "#a9a5ba"; font.pixelSize: 14; wrapMode: Text.WordWrap; visible: text }
            }
        }
    }

    Component {
        id: connectionPage
        PortalConnectionPage {
            onBackRequested: pages.pop()
        }
    }

    Component {
        id: picturePage
        FocusScope {
            id: picture
            property Item lastFocus: null
            Keys.onEscapePressed: pages.pop()
            Keys.onBackPressed: pages.pop()
            StackView.onActivated: Qt.callLater(() => (picture.lastFocus || fitChoice).forceActiveFocus(Qt.TabFocusReason))
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 12
                PageHeader { title: qsTr("Picture & HDR"); onBack: pages.pop() }
                NavRow {
                    id: fitChoice
                    text: qsTr("Screen fit")
                    iconName: "fit"
                    firstInFocusChain: true
                    value: (panel.fitModes[panel.fitList().indexOf(Chiaki.window.videoMode)] || {label: ""}).label
                    onClicked: { picture.lastFocus = fitChoice; panel.openFitPage(); }
                }
                C.Slider {
                    Layout.fillWidth: true
                    visible: Chiaki.window.videoMode === ChiakiWindow.VideoMode.Zoom
                    from: -1; to: 4; stepSize: 0.01
                    value: Chiaki.window.ZoomFactor
                    Accessible.name: qsTr("Zoom amount")
                    onMoved: { Chiaki.window.ZoomFactor = value; Chiaki.settings.sZoomFactor = value; }
                }
                NavRow {
                    id: qualityChoice
                    text: qsTr("Rendering quality")
                    iconName: "quality"
                    value: (panel.qualityModes[panel.presetList().indexOf(Chiaki.window.videoPreset)] || {label: ""}).label
                    onClicked: { picture.lastFocus = qualityChoice; panel.openQualityPage(); }
                }
                NavRow {
                    text: qsTr("Color & HDR")
                    iconName: "hdr"
                    onClicked: panel.displaySettingsRequested()
                }
                NavRow {
                    text: qsTr("Advanced picture settings")
                    iconName: "settings"
                    lastInFocusChain: true
                    onClicked: panel.placeboSettingsRequested()
                }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: qsTr("These change how the stream is shown on this device. Sharpness while moving depends on the bitrate and on the game's own motion blur setting.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                    color: "#8f8ba0"
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    Component {
        id: leavePage
        FocusScope {
            id: leaving
            Keys.onEscapePressed: pages.pop()
            Keys.onBackPressed: pages.pop()
            StackView.onActivated: Qt.callLater(() => restChoice.forceActiveFocus(Qt.TabFocusReason))
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 12
                PageHeader { title: qsTr("Leave Remote Play"); onBack: pages.pop() }
                BigChoice {
                    id: restChoice
                    text: qsTr("Put console in rest mode")
                    detail: qsTr("Saves power. Turn it on again from this app next time.")
                    iconName: "rest"
                    firstInFocusChain: true
                    onClicked: panel.stopRequested(true)
                }
                BigChoice {
                    text: qsTr("Leave console on")
                    detail: qsTr("Keep playing on the TV, or reconnect quickly.")
                    iconName: "power"
                    onClicked: panel.stopRequested(false)
                }
                BigChoice {
                    text: qsTr("Cancel")
                    detail: qsTr("Back to the game menu.")
                    iconName: "back"
                    lastInFocusChain: true
                    onClicked: pages.pop()
                }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: qsTr("To skip this question, choose an action in Settings › General › When you disconnect.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                    color: "#8f8ba0"
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    Component {
        id: optionPage
        FocusScope {
            id: page
            property string title
            property var options: []
            property int selected: -1
            property string note
            property var apply: null
            Keys.onEscapePressed: pages.pop()
            Keys.onBackPressed: pages.pop()
            Component.onCompleted: Qt.callLater(() => {
                const item = optionRepeater.itemAt(Math.max(0, page.selected));
                if (item) item.forceActiveFocus(Qt.TabFocusReason);
            })
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 6
                RowLayout {
                    spacing: 14
                    Layout.bottomMargin: 10
                    RoundButton {
                        Layout.preferredWidth: 46; Layout.preferredHeight: 46
                        focusPolicy: Qt.NoFocus
                        icon.source: "qrc:/icons/portal/back.svg"
                        icon.width: 22; icon.height: 22
                        icon.color: "#ffffff"
                        background: Rectangle { radius: 23; color: "#232a36" }
                        onClicked: pages.pop()
                        Accessible.name: qsTr("Back")
                    }
                    Label { text: page.title; font.pixelSize: 26; color: "#ffffff" }
                }
                Repeater {
                    id: optionRepeater
                    model: page.options
                    C.Button {
                        id: option
                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === page.selected
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(64, optionText.implicitHeight + 24)
                        firstInFocusChain: index === 0
                        lastInFocusChain: index === page.options.length - 1
                        leftPadding: 16; rightPadding: 16
                        background: Rectangle {
                            radius: 14
                            color: option.activeFocus ? "#24344c" : "transparent"
                            border.width: option.activeFocus ? 2 : 0
                            border.color: "#e3efff"
                        }
                        contentItem: RowLayout {
                            spacing: 16
                            Image {
                                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 4
                                sourceSize: Qt.size(56, 56)
                                source: "qrc:/icons/portal/" + option.modelData.icon + ".svg"
                                opacity: 0.85
                            }
                            Column {
                                id: optionText
                                Layout.fillWidth: true
                                spacing: 3
                                Text { width: parent.width; text: option.modelData.label; color: "#ffffff"; font.pixelSize: 18; elide: Text.ElideRight }
                                Text { width: parent.width; text: option.modelData.detail; color: "#a9a5ba"; font.pixelSize: 14; wrapMode: Text.WordWrap }
                            }
                            Image {
                                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                sourceSize: Qt.size(60, 60)
                                source: "qrc:/icons/portal/check.svg"
                                opacity: option.chosen ? 1 : 0
                            }
                        }
                        onClicked: {
                            page.selected = index;
                            if (page.apply) page.apply(index);
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    text: page.note
                    visible: text
                    color: "#c9c5d8"
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
