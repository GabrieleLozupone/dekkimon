import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.streetpea.chiaking

Pane {
    padding: 0
    id: consolePane
    StackView.onActivated: {
        forceActiveFocus(Qt.TabFocusReason);
        if(!Chiaki.autoConnect && !root.initialAsk && !Chiaki.window.directStream)
        {
            root.initialAsk = true;
            // The installer adds the Steam shortcut, so only the PSN sign-in is suggested here.
            if(Chiaki.settings.remotePlayAsk)
            {
                if(!Chiaki.settings.psnRefreshToken || !Chiaki.settings.psnAuthToken || !Chiaki.settings.psnAuthTokenExpiry || !Chiaki.settings.psnAccountId)
                    root.showRemindDialog(qsTr("Remote Play via PSN"), qsTr("Sign in to PlayStation Network to register consoles automatically and to play away from home without port forwarding.") + "\n\n" + qsTr("You can do this later in Settings › Remote access."), true, () => root.showPSNTokenDialog(false));
                else
                    Chiaki.settings.remotePlayAsk = false;
            }
        }
    }
    // Keep backend indices: hidden and duplicate hosts still occupy entries there.
    readonly property var availableHosts: {
        let entries = [];
        for (let i = 0; i < Chiaki.hosts.length; ++i) {
            const host = Chiaki.hosts[i];
            if (host.display)
                entries.push({ backendIndex: i, host: host,
                    key: (host.mac || host.duid || host.address || host.name) + ":" + !!host.discovered });
        }
        return entries;
    }
    property bool browsingConsoles: false
    property int homeAction: 0
    property string selectedKey: ""
    // consoleIndex == availableHosts.length selects the "Add console" card (consoles screen only).
    property int consoleIndex: -1
    readonly property var selectedEntry: consoleIndex >= 0
        && consoleIndex < availableHosts.length ? availableHosts[consoleIndex] : null
    readonly property var selectedHost: selectedEntry ? selectedEntry.host : null

    function restoreSelection() {
        let selected = availableHosts.findIndex(entry => entry.key === selectedKey);
        if (browsingConsoles && consoleIndex === availableHosts.length && selected < 0)
            return;   // keep "Add console" selected
        consoleIndex = availableHosts.length ? Math.max(0, selected) : (browsingConsoles ? 0 : -1);
        rememberSelection();
    }
    function rememberSelection() {
        if (selectedEntry)
            selectedKey = selectedEntry.key;
    }
    function selectConsole(step) {
        const count = availableHosts.length + 1;   // + "Add console"
        consoleIndex = ((Math.max(0, consoleIndex) + step) % count + count) % count;
        rememberSelection();
    }
    function activateConsole(index) {
        consoleIndex = index;
        rememberSelection();
        if (selectedEntry) connectSelected();
        else openManage();
    }
    onBrowsingConsolesChanged: {
        if (!browsingConsoles && !selectedEntry) restoreSelection();
        else if (browsingConsoles && consoleIndex < 0) consoleIndex = 0;
    }
    function connectSelected() {
        if (!selectedEntry)
            return;
        if (typeof root.portalConsoleName !== "undefined")
            root.portalConsoleName = Chiaki.settings.streamerMode ? "" : (selectedHost.name || "");
        if (selectedHost.discovered)
            Chiaki.connectToHost(selectedEntry.backendIndex, selectedHost.name);
        else
            Chiaki.connectToHost(selectedEntry.backendIndex);
    }
    function removeSelected() {
        if (!selectedEntry)
            return;
        const entry = selectedEntry;
        if (entry.host.manual)
            root.showConfirmDialog(qsTr("Delete Console"), qsTr("Are you sure you want to delete this console?"),
                () => Chiaki.deleteHost(entry.backendIndex));
        else if (entry.host.discovered && !entry.host.registered)
            root.showConfirmDialog(qsTr("Hide Console"),
                qsTr("Hide this console? You can restore it in Settings under Hidden Consoles."),
                () => Chiaki.hideHost(entry.host.mac, entry.host.name));
    }
    function connectionLabel(host) {
        if (!host.registered)
            return qsTr("Set up");
        if (host.state === "standby")
            return qsTr("Wake and connect");
        return qsTr("Connect");
    }
    function statusLabel(host) {
        if (!host.registered)
            return qsTr("Ready to pair");
        if (host.state === "standby")
            return qsTr("Rest mode");
        if (host.discovered)
            return qsTr("Available on your network");
        if (host.duid)
            return qsTr("Connect via PlayStation Network");
        return qsTr("Saved console");
    }
    onAvailableHostsChanged: Qt.callLater(restoreSelection)
    Component.onCompleted: restoreSelection()

    Keys.onUpPressed: { if (browsingConsoles) selectConsole(-1); else homeAction = (homeAction + 2) % 3; }
    Keys.onDownPressed: { if (browsingConsoles) selectConsole(1); else homeAction = (homeAction + 1) % 3; }
    Keys.onLeftPressed: { if (browsingConsoles) selectConsole(-1); else homeAction = (homeAction + 2) % 3; }
    Keys.onRightPressed: { if (browsingConsoles) selectConsole(1); else homeAction = (homeAction + 1) % 3; }
    Keys.onMenuPressed: quickDrawer.open()
    Keys.onReturnPressed: {
        if (!browsingConsoles && homeAction === 1) browsingConsoles = true;
        else if (!browsingConsoles && homeAction === 2) quickDrawer.open();
        else if (browsingConsoles) activateConsole(consoleIndex);
        else if (selectedEntry) connectSelected();
        else openManage();
    }
    Keys.onYesPressed: openManage()
    Keys.onNoPressed: { if (selectedEntry) openOptions(); }
    Keys.onEscapePressed: {
        if (browsingConsoles) {
            browsingConsoles = false;
            homeAction = 0;
        } else {
            root.showConfirmDialog(qsTr("Quit"), qsTr("Are you sure you want to quit?"), () => Qt.quit());
        }
    }
    Keys.onPressed: (event) => {
        if (event.modifiers)
            return;
        switch (event.key) {
        case Qt.Key_PageUp:
            browsingConsoles = !browsingConsoles;
            event.accepted = true;
            break;
        case Qt.Key_PageDown:
            browsingConsoles = !browsingConsoles;
            event.accepted = true;
            break;
        case Qt.Key_F1:
            if (typeof Chiaki.createSteamShortcut === "function") root.showSteamShortcutDialog(false);
            event.accepted = true;
            break;
        case Qt.Key_F2:
            root.showManualHostDialog();
            event.accepted = true;
            break;
        }
    }

    background: Rectangle { color: "#101116" }
    Connections {
        // Back grip (L4/R4) or the stream-menu combo: toggle the quick menu on the home screen.
        // Only a real QObject (test mocks provide a plain JS object).
        target: Chiaki.window && Chiaki.window.objectName !== undefined ? Chiaki.window : null
        ignoreUnknownSignals: true
        function onMenuRequested() {
            if (!consolePane.visible || consolePane.browsingConsoles)
                return;
            if (quickDrawer.opened) quickDrawer.close(); else quickDrawer.open();
        }
    }
    PortalHome {
        anchors.fill: parent
        visible: !consolePane.browsingConsoles
        consoleName: !consolePane.selectedHost ? "" : Chiaki.settings.streamerMode
            ? qsTr("Your PlayStation") : (consolePane.selectedHost.name || qsTr("PlayStation"))
        connectText: consolePane.selectedHost ? consolePane.connectionLabel(consolePane.selectedHost) : qsTr("Set up console")
        statusText: consolePane.selectedHost ? consolePane.statusLabel(consolePane.selectedHost)
            : qsTr("Turn on your console or leave it in rest mode, then add it from Consoles.")
        currentAction: consolePane.homeAction
        sidebar: quickDrawer.position
        controllerConnected: Chiaki.controllers.length > 0
        onHomeRequested: consolePane.homeAction = 0
        onConnectRequested: { if(consolePane.selectedEntry) consolePane.connectSelected(); else consolePane.openManage(); }
        onConsolesRequested: { consolePane.browsingConsoles = true; consolePane.forceActiveFocus(); }
        onQuickMenuRequested: quickDrawer.open()
        onConnectionRequested: { quickDrawer.open(); quickPanel.openConnectionPage(); }
    }
    // Poll the link while the home screen is up (Chiaki.wifi feeds the corner and the menu).
    Binding {
        target: Chiaki.wifi ? Chiaki.wifi : null; property: "active"
        value: true; when: consolePane.visible && !Chiaki.session && !!Chiaki.wifi
        restoreMode: Binding.RestoreNone
    }
    // Quick menu: a plain sliding panel rather than a Drawer popup. chiaki-ng renders QML into
    // an offscreen window whose popup overlay has no usable size, so a Drawer (positioned
    // against that overlay) opens off screen. The stream menu uses the same approach.
    Item {
        id: quickDrawer
        objectName: "quickDrawer"
        property bool opened: false
        property real position: opened ? 1 : 0
        // A single tap can arrive as touch and as an emulated click; ignore outside taps briefly.
        property bool justOpened: false
        anchors.fill: parent
        z: 10
        visible: position > 0
        Behavior on position { NumberAnimation { duration: quickDrawer.opened ? 240 : 200; easing.type: quickDrawer.opened ? Easing.OutCubic : Easing.InCubic } }
        function open() {
            if (opened) return;
            console.info("quick menu: opening");
            justOpened = true;
            drawerGuard.restart();
            opened = true;
            quickPanel.initialFocusItem.forceActiveFocus(Qt.TabFocusReason);
        }
        function close() {
            if (!opened) return;
            console.info("quick menu: closed");
            opened = false;
            // Release focus inside the panel first: focusing the home pane would otherwise restore
            // its remembered sub-focus, i.e. the now hidden panel, and swallow all further input.
            quickPanel.focus = false;
            consolePane.forceActiveFocus(Qt.TabFocusReason);
        }
        Timer { id: drawerGuard; interval: 400; onTriggered: quickDrawer.justOpened = false }
        // Keys the panel does not handle must not reach the home screen behind it.
        Keys.onPressed: event => { if (quickDrawer.opened) event.accepted = true; }
        Rectangle {
            anchors.fill: parent
            color: "#59000008"
            opacity: quickDrawer.position
            MouseArea {
                anchors.fill: parent
                enabled: quickDrawer.opened
                onClicked: if (!quickDrawer.justOpened) quickDrawer.close()
            }
        }
        Item {
            width: Math.min(consolePane.width, Math.max(400, Math.round(consolePane.width * 0.37)))
            height: parent.height
            x: parent.width - width * quickDrawer.position
            MouseArea { anchors.fill: parent }   // swallow taps on the panel background
            PortalQuickMenu {
                id: quickPanel
                anchors.fill: parent
                onCloseRequested: quickDrawer.close()
                onConsolesRequested: { quickDrawer.close(); consolePane.browsingConsoles = true; }
                onStreamSettingsRequested: { quickDrawer.close(); root.showSettingsDialog(2); }
                onSettingsRequested: { quickDrawer.close(); root.showSettingsDialog(); }
            }
        }
    }
    PortalConsoles {
        id: consolesView
        anchors.fill: parent
        visible: consolePane.browsingConsoles
        entries: consolePane.availableHosts
        currentIndex: Math.max(0, consolePane.consoleIndex)
        controllerConnected: Chiaki.controllers.length > 0
        streamerMode: !!Chiaki.settings.streamerMode
        connectionLabel: host => consolePane.connectionLabel(host)
        statusLabel: host => consolePane.statusLabel(host)
        onSelectRequested: index => { consolePane.consoleIndex = index; consolePane.rememberSelection(); consolePane.forceActiveFocus(); }
        onActivateRequested: index => consolePane.activateConsole(index)
        onOptionsRequested: consolePane.openOptions()
        onManageRequested: consolePane.openManage()
        onBackRequested: { consolePane.browsingConsoles = false; consolePane.homeAction = 0; }
        onHomeRequested: { consolePane.browsingConsoles = false; consolePane.homeAction = 0; }
        onQuickMenuRequested: { consolePane.browsingConsoles = false; quickDrawer.open(); }
        onConnectionRequested: { consolePane.browsingConsoles = false; quickDrawer.open(); quickPanel.openConnectionPage(); }
    }

    // ---- Console options / Add & manage: a side panel in the quick-menu style ------------
    function openOptions() {
        const host = selectedHost;
        if (!host) return;
        const address = Chiaki.settings.streamerMode ? qsTr("Hidden") : (host.address || qsTr("PlayStation Network"));
        const id = Chiaki.settings.streamerMode ? qsTr("Hidden") : (host.mac || qsTr("Not available"));
        actionPanel.title = consolesView.displayName(host);
        actionPanel.subtitle = statusLabel(host);
        actionPanel.info = qsTr("Address: %1\nID: %2").arg(address).arg(id);
        actionPanel.actions = [
            { text: connectionLabel(host), icon: "controller", run: () => consolePane.connectSelected() },
            { text: qsTr("Wake up"), detail: qsTr("Turn the console on without connecting."), icon: "power",
              isVisible: () => !!consolePane.selectedHost && consolePane.selectedHost.registered
                  && !consolePane.selectedHost.discovered && !consolePane.selectedHost.duid,
              run: () => Chiaki.wakeUpHost(consolePane.selectedEntry.backendIndex) },
            { text: qsTr("Update console PIN"), detail: qsTr("If the console asks for a new PIN."), icon: "settings",
              isVisible: () => !!consolePane.selectedHost && consolePane.selectedHost.registered,
              run: () => root.showConsolePinDialog(consolePane.selectedEntry.backendIndex) },
            { text: host.manual ? qsTr("Delete console") : qsTr("Hide console"), danger: true,
              detail: host.manual ? qsTr("Remove this saved console.") : qsTr("You can show it again in Settings › Consoles."),
              icon: "disconnect",
              isVisible: () => !!consolePane.selectedHost && (consolePane.selectedHost.manual
                  || (consolePane.selectedHost.discovered && !consolePane.selectedHost.registered)),
              run: () => consolePane.removeSelected() }
        ];
        actionDrawer.open();
    }
    function openManage() {
        actionPanel.title = qsTr("Add / manage");
        actionPanel.subtitle = qsTr("Find and set up consoles.");
        actionPanel.info = "";
        actionPanel.actions = [
            { text: Chiaki.settings.psnAuthToken ? qsTr("Refresh PlayStation Network consoles") : qsTr("Sign in to PlayStation Network"),
              detail: qsTr("Registers your consoles and lets you play away from home."), icon: "globe",
              run: () => { if (Chiaki.settings.psnAuthToken) Chiaki.refreshPsnToken(); else root.showPSNTokenDialog(false); } },
            { text: qsTr("Add console manually"), detail: qsTr("Enter the console's address."), icon: "plus",
              run: () => root.showManualHostDialog() },
            { text: qsTr("Discover nearby consoles"), detail: qsTr("Look for consoles on this network."), icon: "signal",
              toggle: true, isOn: () => Chiaki.discoveryEnabled, run: () => Chiaki.discoveryEnabled = !Chiaki.discoveryEnabled },
            { text: qsTr("Create Steam shortcut"), detail: qsTr("Artwork and controller layout for Steam."), icon: "controller",
              isVisible: () => typeof Chiaki.createSteamShortcut === "function",
              run: () => root.showSteamShortcutDialog(false) },
            { text: qsTr("Settings"), icon: "settings", run: () => root.showSettingsDialog() },
            { text: qsTr("Quit"), icon: "power", danger: true,
              run: () => root.showConfirmDialog(qsTr("Quit"), qsTr("Are you sure you want to quit?"), () => Qt.quit()) }
        ];
        actionDrawer.open();
    }
    Item {
        id: actionDrawer
        objectName: "actionDrawer"
        property bool opened: false
        property real position: opened ? 1 : 0
        property bool justOpened: false
        anchors.fill: parent
        z: 11
        visible: position > 0
        Behavior on position { NumberAnimation { duration: actionDrawer.opened ? 240 : 200; easing.type: actionDrawer.opened ? Easing.OutCubic : Easing.InCubic } }
        function open() {
            justOpened = true;
            actionGuard.restart();
            opened = true;
            Qt.callLater(() => actionPanel.focusFirst());
        }
        function close() {
            if (!opened) return;
            opened = false;
            actionPanel.focus = false;
            consolePane.forceActiveFocus(Qt.TabFocusReason);
        }
        Timer { id: actionGuard; interval: 400; onTriggered: actionDrawer.justOpened = false }
        Keys.onPressed: event => { if (actionDrawer.opened) event.accepted = true; }
        Rectangle {
            anchors.fill: parent
            color: "#59000008"
            opacity: actionDrawer.position
            MouseArea {
                anchors.fill: parent
                enabled: actionDrawer.opened
                onClicked: if (!actionDrawer.justOpened) actionDrawer.close()
            }
        }
        Item {
            width: Math.min(consolePane.width, Math.max(400, Math.round(consolePane.width * 0.37)))
            height: parent.height
            x: parent.width - width * actionDrawer.position
            MouseArea { anchors.fill: parent }
            PortalActionPanel {
                id: actionPanel
                objectName: "actionPanel"
                anchors.fill: parent
                onCloseRequested: actionDrawer.close()
            }
        }
    }
}
