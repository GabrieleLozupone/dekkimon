import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import "controls" as C
import "controls/SpatialNav.js" as Nav

// Portal-style settings browser: a stack of pages, each a list of rows built from plain
// descriptors (see PortalSettingsModel.qml). Rows only call the getter/setter they are
// given, so the stored settings and their effect are exactly those of the old dialogs.
//
// Descriptor fields (all optional except type/label):
//   type     "header" | "choice" | "toggle" | "slider" | "page" | "action" | "note"
//   label, detail, icon
//   visible  () => bool
//   get/set  choice: option index, toggle: bool, slider: number
//   options  choice: [{ label, detail }]
//   from, to, step, decimals, unit, def    slider (def = default, ✕ resets to it)
//   items    page: descriptor array, or () => array;  note: footnote for the page
//   value    page/action: () => string shown on the right
//   run      action: (settingsView) => void
//   text     type "text": get/set a string, placeholder, inputHint (Qt.ImhDigitsOnly...),
//            secret () => bool (mask the input, e.g. streamer mode), maxLength
//   enabled  () => bool: row shown greyed out and skipped by focus while false
//   fmt      slider: (value) => string shown instead of the number
//   reset    slider: () => void called by ✕ instead of setting def
//   card     note: draw as an info card; icon optional
FocusScope {
    id: ps
    Material.theme: Material.Dark
    Material.accent: "#cfe3ff"
    Material.foreground: "#f4f2fa"
    property bool spatialNavScope: true
    property string title
    property var items: []
    property string note
    readonly property int depth: stack.depth
    signal closeRequested()

    function glyph(name) {
        return typeof root !== "undefined" && root.controllerButton ? root.controllerButton(name) : "";
    }
    function resolve(list) { return typeof list === "function" ? list() : (list || []); }
    function shown(d) { return !d.visible || !!d.visible(); }
    function back() {
        if (stack.depth > 1) stack.pop();
        else ps.closeRequested();
    }
    function openPage(d) {
        stack.push(listPage, { title: d.label, source: d.items, note: d.note || "" });
    }
    function openChoice(d) {
        stack.push(choicePage, { descriptor: d });
    }
    function focusCurrent() {
        if (stack.currentItem) stack.currentItem.restoreFocus();
    }
    onActiveFocusChanged: if (activeFocus && stack.currentItem && !stack.currentItem.activeFocus) focusCurrent()
    Component.onCompleted: stack.push(listPage, { title: ps.title, source: Qt.binding(() => ps.items), note: ps.note, isRoot: true }, StackView.Immediate)

    Keys.onEscapePressed: event => { ps.back(); event.accepted = true; }
    Keys.onBackPressed: event => { ps.back(); event.accepted = true; }

    StackView {
        id: stack
        anchors.fill: parent
        clip: true
        pushEnter: Transition { NumberAnimation { property: "x"; from: stack.width * 0.12; to: 0; duration: 200; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } }
        pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
        popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 } }
        popExit: Transition { NumberAnimation { property: "x"; from: 0; to: stack.width * 0.12; duration: 180; easing.type: Easing.InCubic }
                              NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 160 } }
        onCurrentItemChanged: Qt.callLater(ps.focusCurrent)
    }

    // ---- page chrome -------------------------------------------------------------------
    component PageHeader: RowLayout {
        id: hdr
        property string text
        property bool showBack: true
        spacing: 16
        RoundButton {
            Layout.preferredWidth: 48; Layout.preferredHeight: 48
            focusPolicy: Qt.NoFocus
            icon.source: "qrc:/icons/portal/back.svg"
            icon.width: 22; icon.height: 22
            icon.color: "#ffffff"
            background: Rectangle { radius: 24; color: parent.hovered ? "#2d3544" : "#232a36" }
            onClicked: ps.back()
            Accessible.name: qsTr("Back")
        }
        Label {
            Layout.fillWidth: true
            text: hdr.text
            font.pixelSize: 28
            color: "#ffffff"
            elide: Text.ElideRight
        }
    }
    component Hint: Row {
        property string glyphName
        property string label
        spacing: 8
        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!source.toString()
            width: 24; height: 24; sourceSize: Qt.size(48, 48)
            source: parent.glyphName ? ps.glyph(parent.glyphName) : ""
        }
        Label { anchors.verticalCenter: parent.verticalCenter; text: parent.label; color: "#cfccd9"; font.pixelSize: 15 }
    }
    component HintBar: Row {
        id: hints
        property bool sliderFocused: false
        property bool canReset: false
        spacing: 22
        Hint { visible: hints.sliderFocused; label: qsTr("◀ ▶  Adjust") }
        Hint { visible: hints.sliderFocused; label: qsTr("L1 / R1  Fine") }
        Hint { visible: hints.sliderFocused && hints.canReset; glyphName: "cross"; label: qsTr("Default") }
        Hint { visible: !hints.sliderFocused; glyphName: "cross"; label: qsTr("Select") }
        Hint { glyphName: "moon"; label: qsTr("Back") }
    }
    // Shared scrolling body: keeps the focused row on screen.
    component ScrollBody: Flickable {
        id: flick
        default property alias content: column.data
        property alias column: column
        contentHeight: column.implicitHeight + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Behavior on contentY { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        ColumnLayout {
            id: column
            width: Math.min(flick.width - 24, 860)
            x: Math.max(0, (flick.width - width) / 2)
            spacing: 10
        }
        function ensureVisible(item) {
            let a = item;
            while (a && a !== column) a = a.parent;
            if (!a) return;
            const top = item.mapToItem(column, 0, 0).y;
            const bottom = top + item.height;
            if (top - 16 < contentY) contentY = Math.max(0, top - 70);
            else if (bottom + 16 > contentY + height)
                contentY = Math.min(Math.max(0, contentHeight - height), bottom - height + 70);
        }
        Connections {
            target: flick.Window.window
            function onActiveFocusItemChanged() {
                const w = flick.Window.window;
                if (w && w.activeFocusItem && flick.visible) flick.ensureVisible(w.activeFocusItem);
            }
        }
    }

    // ---- rows ----------------------------------------------------------------------------
    component RowBackground: Rectangle {
        property bool focused: false
        property bool hovered: false
        radius: 16
        color: focused ? "#24344c" : hovered ? "#222833" : "#1a1e27"
        border.width: focused ? 2 : 0
        border.color: "#e3efff"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    component SectionHeader: Label {
        property var d
        Layout.fillWidth: true
        Layout.topMargin: 14
        Layout.leftMargin: 6
        text: d ? d.label : ""
        font.pixelSize: 15
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        color: "#8fb8ff"
        property Item focusTarget: null
    }
    component NoteRow: Label {
        id: noteRow
        property var d
        readonly property bool card: !!(d && d.card)
        Layout.fillWidth: true
        Layout.leftMargin: card ? 0 : 6
        text: d ? (typeof d.label === "function" ? d.label() : d.label) : ""
        wrapMode: Text.WordWrap
        font.pixelSize: card ? 18 : 15
        color: card ? "#ffffff" : "#c9c5d8"
        padding: card ? 20 : 0
        leftPadding: card ? (d && d.icon ? 66 : 22) : 0
        background: Rectangle {
            visible: noteRow.card
            radius: 16
            color: noteRow.d && noteRow.d.tone === "good" ? "#173a2a" : "#1a1e27"
            Image {
                visible: !!(noteRow.d && noteRow.d.icon)
                x: 22; anchors.verticalCenter: parent.verticalCenter
                width: 30; height: 30; sourceSize: Qt.size(60, 60)
                source: noteRow.d && noteRow.d.icon ? "qrc:/icons/portal/" + noteRow.d.icon + ".svg" : ""
            }
        }
        property Item focusTarget: null
    }
    // Text entry row (e.g. a custom resolution). ✕ starts editing, ✕ or B finishes.
    component TextRow: RowBackground {
        id: trow
        property var d
        property Item focusTarget: field
        Layout.fillWidth: true
        implicitHeight: 76
        focused: field.activeFocus
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 22; anchors.rightMargin: 16
            spacing: 18
            Column {
                Layout.fillWidth: true
                spacing: 3
                Text { width: parent.width; text: trow.d ? trow.d.label : ""; color: "#ffffff"; font.pixelSize: 18; elide: Text.ElideRight }
                Text { width: parent.width; visible: text; text: trow.d && trow.d.detail ? trow.d.detail : ""
                       color: "#a9a5ba"; font.pixelSize: 14; wrapMode: Text.WordWrap }
            }
            C.TextField {
                id: field
                Layout.preferredWidth: 200
                horizontalAlignment: Text.AlignRight
                text: trow.d ? String(trow.d.get()) : ""
                // Hidden while focused: the Material field would float it over its top edge.
                placeholderText: !field.activeFocus && trow.d && trow.d.placeholder ? trow.d.placeholder : ""
                inputMethodHints: trow.d && trow.d.inputHint ? trow.d.inputHint : Qt.ImhNone
                echoMode: trow.d && trow.d.secret && trow.d.secret() ? TextInput.Password : TextInput.Normal
                maximumLength: trow.d && trow.d.maxLength ? trow.d.maxLength : 32767
                onEditingFinished: { if (trow.d) { trow.d.set(text); text = Qt.binding(() => trow.d ? String(trow.d.get()) : ""); } }
                Accessible.name: trow.d ? trow.d.label : ""
            }
        }
    }
    component NavRow: C.Button {
        id: row
        property var d
        property Item focusTarget: row
        readonly property bool isToggle: d && d.type === "toggle"
        readonly property bool on: isToggle && !!d.get()
        readonly property string valueText: {
            if (!d) return "";
            if (d.type === "choice") {
                const o = d.options[d.get()];
                return o ? o.label : "";
            }
            if (d.value) return d.value();
            return "";
        }
        text: d ? d.label : ""
        enabled: !d || !d.enabled || !!d.enabled()
        Layout.fillWidth: true
        implicitHeight: Math.max(72, rowText.implicitHeight + 26)
        leftPadding: 22; rightPadding: 20
        background: RowBackground { focused: row.activeFocus; hovered: row.hovered; opacity: row.enabled ? 1 : 0.5 }
        contentItem: RowLayout {
            spacing: 18
            Image {
                visible: !!(row.d && row.d.icon)
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                sourceSize: Qt.size(56, 56)
                source: row.d && row.d.icon ? "qrc:/icons/portal/" + row.d.icon + ".svg" : ""
            }
            Column {
                id: rowText
                Layout.fillWidth: true
                spacing: 3
                Text { width: parent.width; text: row.d ? row.d.label : ""; color: "#ffffff"; font.pixelSize: 18; elide: Text.ElideRight }
                Text {
                    width: parent.width
                    visible: text
                    text: !row.d || !row.d.detail ? "" : typeof row.d.detail === "function" ? row.d.detail() : row.d.detail
                    color: "#a9a5ba"; font.pixelSize: 14; wrapMode: Text.WordWrap
                }
            }
            Text {
                visible: !row.isToggle && text
                Layout.maximumWidth: row.width * 0.38
                text: row.valueText; color: "#cfd9ea"; font.pixelSize: 16
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
            Image {
                visible: !row.isToggle && row.d && row.d.type !== "action"
                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                sourceSize: Qt.size(36, 36)
                source: "qrc:/icons/portal/chevron.svg"
                opacity: 0.6
            }
            Rectangle {
                visible: row.isToggle
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
            if (!d) return;
            if (d.type === "toggle") d.set(!d.get());
            else if (d.type === "choice") ps.openChoice(d);
            else if (d.type === "page") ps.openPage(d);
            else if (d.type === "action" && d.run) d.run(ps);
        }
        Accessible.name: d ? d.label : ""
    }
    component SliderRow: RowBackground {
        id: srow
        property var d
        property Item focusTarget: slider
        readonly property int decimals: d && d.decimals !== undefined ? d.decimals : 0
        function fmt(v) {
            if (d && d.fmt) return d.fmt(v);
            return Number(v).toFixed(decimals) + (d && d.unit ? " " + d.unit : "");
        }
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 28
        focused: slider.activeFocus
        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            anchors.leftMargin: 22; anchors.rightMargin: 22
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: srow.d ? srow.d.label : ""; color: "#ffffff"; font.pixelSize: 18; elide: Text.ElideRight }
                Text { text: srow.fmt(slider.value); color: "#ffffff"; font.pixelSize: 17; font.weight: Font.DemiBold }
            }
            Text {
                Layout.fillWidth: true
                visible: text
                text: {
                    if (!srow.d) return "";
                    const def = srow.d.defText ? srow.d.defText
                        : srow.d.def !== undefined ? qsTr("Default %1.").arg(srow.fmt(srow.d.def)) : "";
                    return [srow.d.detail || "", def].filter(s => s).join(" ");
                }
                color: "#a9a5ba"; font.pixelSize: 14; wrapMode: Text.WordWrap
            }
            Slider {
                id: slider
                Layout.fillWidth: true
                Material.accent: "#ffffff"
                from: srow.d ? srow.d.from : 0
                to: srow.d ? srow.d.to : 1
                stepSize: srow.d ? srow.d.step : 0.01
                value: srow.d ? srow.d.get() : 0
                focusPolicy: Qt.StrongFocus
                Accessible.name: srow.d ? srow.d.label : ""
                // Coarse steps for the d-pad on very fine ranges; L1/R1 keep the original step.
                readonly property real coarseStep: {
                    const range = to - from;
                    if (range / stepSize <= 120) return stepSize;
                    const raw = range / 100;
                    const p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10));
                    const m = raw / p;
                    const nice = (m < 1.5 ? 1 : m < 3.5 ? 2 : m < 7.5 ? 5 : 10) * p;
                    return Math.max(stepSize, nice);
                }
                function nudge(delta) {
                    let v = Math.min(to, Math.max(from, value + delta));
                    v = Math.round(v / stepSize) * stepSize;
                    v = Number(v.toFixed(6));
                    if (v === value) return;
                    value = v;
                    if (srow.d) srow.d.set(v);
                }
                onMoved: if (srow.d) srow.d.set(Number(value.toFixed(6)))
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Left: nudge(-coarseStep); event.accepted = true; break;
                    case Qt.Key_Right: nudge(coarseStep); event.accepted = true; break;
                    case Qt.Key_PageUp: nudge(-stepSize); event.accepted = true; break;
                    case Qt.Key_PageDown: nudge(stepSize); event.accepted = true; break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (srow.d && srow.d.reset) { srow.d.reset(); value = Qt.binding(() => srow.d ? srow.d.get() : 0); }
                        else if (srow.d && srow.d.def !== undefined) { value = srow.d.def; srow.d.set(srow.d.def); }
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                    case Qt.Key_Down:
                        if (Nav.handleKey(slider, event, false)) event.accepted = true;
                        break;
                    }
                }
            }
        }
    }

    // ---- pages ---------------------------------------------------------------------------
    Component {
        id: listPage
        FocusScope {
            id: page
            property string title
            // Array of descriptors, or a function returning one (re-evaluated when the
            // settings it reads change, e.g. the registered console list).
            property var source: []
            readonly property var items: ps.resolve(source)
            property string note
            property bool isRoot: false
            property Item lastFocus: null
            function restoreFocus() {
                if (lastFocus && lastFocus !== page && lastFocus.visible) { lastFocus.forceActiveFocus(Qt.TabFocusReason); return; }
                for (let i = 0; i < rows.count; ++i) {
                    const l = rows.itemAt(i);
                    if (l && l.visible && l.item && l.item.focusTarget) {
                        l.item.focusTarget.forceActiveFocus(Qt.TabFocusReason);
                        return;
                    }
                }
            }
            Connections {
                target: page.Window.window
                function onActiveFocusItemChanged() {
                    const w = page.Window.window;
                    if (!w || !w.activeFocusItem) return;
                    // Remember rows only: the StackView focuses the page itself on push.
                    if (w.activeFocusItem === page) return;
                    let a = w.activeFocusItem;
                    while (a && a !== page) a = a.parent;
                    if (a) page.lastFocus = w.activeFocusItem;
                }
            }
            onActiveFocusChanged: if (activeFocus && Window.window && Window.window.activeFocusItem === page) Qt.callLater(restoreFocus)
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 18; anchors.bottomMargin: 14
                anchors.leftMargin: 24; anchors.rightMargin: 24
                spacing: 12
                PageHeader {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 860
                    Layout.alignment: Qt.AlignHCenter
                    text: page.title
                }
                ScrollBody {
                    id: body
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Repeater {
                        id: rows
                        model: page.items
                        delegate: Loader {
                            id: rowLoader
                            required property var modelData
                            Layout.fillWidth: true
                            visible: ps.shown(modelData)
                            sourceComponent: modelData.type === "header" ? headerC
                                : modelData.type === "note" ? noteC
                                : modelData.type === "slider" ? sliderC
                                : modelData.type === "text" ? textC : navC
                            Component { id: headerC; SectionHeader { d: rowLoader.modelData } }
                            Component { id: noteC; NoteRow { d: rowLoader.modelData } }
                            Component { id: sliderC; SliderRow { d: rowLoader.modelData } }
                            Component { id: navC; NavRow { d: rowLoader.modelData } }
                            Component { id: textC; TextRow { d: rowLoader.modelData } }
                        }
                    }
                    NoteRow {
                        Layout.topMargin: 8
                        visible: !!page.note
                        d: ({ label: page.note })
                    }
                }
                HintBar {
                    Layout.alignment: Qt.AlignHCenter
                    sliderFocused: {
                        const w = page.Window.window;
                        const f = w ? w.activeFocusItem : null;
                        return !!f && f instanceof Slider;
                    }
                    canReset: true
                }
            }
        }
    }

    Component {
        id: choicePage
        FocusScope {
            id: cpage
            property var descriptor
            property int selected: descriptor ? descriptor.get() : -1
            function restoreFocus() {
                const item = options.itemAt(Math.max(0, cpage.selected));
                if (item) item.forceActiveFocus(Qt.TabFocusReason);
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 18; anchors.bottomMargin: 14
                anchors.leftMargin: 24; anchors.rightMargin: 24
                spacing: 12
                PageHeader {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 860
                    Layout.alignment: Qt.AlignHCenter
                    text: cpage.descriptor ? cpage.descriptor.label : ""
                }
                ScrollBody {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    NoteRow {
                        visible: !!(cpage.descriptor && cpage.descriptor.detail)
                        Layout.bottomMargin: 6
                        d: ({ label: cpage.descriptor && cpage.descriptor.detail ? cpage.descriptor.detail : "" })
                    }
                    Repeater {
                        id: options
                        model: cpage.descriptor ? cpage.descriptor.options : []
                        C.Button {
                            id: option
                            required property var modelData
                            required property int index
                            readonly property bool chosen: index === cpage.selected
                            Layout.fillWidth: true
                            implicitHeight: Math.max(64, optionText.implicitHeight + 24)
                            leftPadding: 18; rightPadding: 16
                            background: Rectangle {
                                radius: 14
                                color: option.activeFocus ? "#24344c" : option.chosen ? "#161b24" : "transparent"
                                border.width: option.activeFocus ? 2 : 0
                                border.color: "#e3efff"
                            }
                            contentItem: RowLayout {
                                spacing: 16
                                Column {
                                    id: optionText
                                    Layout.fillWidth: true
                                    spacing: 3
                                    Text { width: parent.width; text: option.modelData.label; color: "#ffffff"; font.pixelSize: 18; elide: Text.ElideRight }
                                    Text {
                                        width: parent.width
                                        visible: text
                                        text: option.modelData.detail || ""
                                        color: "#a9a5ba"; font.pixelSize: 14; wrapMode: Text.WordWrap
                                    }
                                }
                                Image {
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                    sourceSize: Qt.size(60, 60)
                                    source: "qrc:/icons/portal/check.svg"
                                    opacity: option.chosen ? 1 : 0
                                }
                            }
                            onClicked: {
                                cpage.descriptor.set(index);
                                cpage.selected = cpage.descriptor.get();
                            }
                        }
                    }
                    NoteRow {
                        Layout.topMargin: 8
                        visible: !!(cpage.descriptor && cpage.descriptor.note)
                        d: ({ label: cpage.descriptor && cpage.descriptor.note ? cpage.descriptor.note : "" })
                    }
                }
                HintBar { Layout.alignment: Qt.AlignHCenter }
            }
        }
    }
}
