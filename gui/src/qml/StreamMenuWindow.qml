import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Window

import org.streetpea.chiaking
import "controls" as C

Window {
    id: streamMenuWindow

    property bool open: false
    property bool closing: false

    signal closeRequested()
    signal displaySettingsRequested()
    signal placeboSettingsRequested()
    signal mainViewRequested()
    signal closeAnimationFinished()

    visible: open || closing
    flags: Qt.Tool | Qt.FramelessWindowHint
    color: "transparent"
    modality: Qt.NonModal

    function focusInitialItem() {
        requestActivate();
        quickPanel.initialFocusItem.forceActiveFocus(Qt.TabFocusReason);
    }

    onVisibleChanged: {
        if (visible)
            focusTimer.restart();
    }

    onActiveChanged: {
        if (active && visible)
            focusTimer.restart();
    }

    Shortcut {
        sequence: StandardKey.Cancel
        onActivated: streamMenuWindow.closeRequested()
    }

    Shortcut {
        sequence: "Ctrl+O"
        onActivated: {
            if (streamMenuWindow.open)
                streamMenuWindow.closeRequested();
        }
    }

    Behavior on x {
        NumberAnimation {
            id: menuAnimation
            duration: 250
            onRunningChanged: {
                if (!running && !streamMenuWindow.open)
                    streamMenuWindow.closeAnimationFinished();
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (streamMenuWindow.visible)
                streamMenuWindow.focusInitialItem();
        }
    }

    PortalQuickMenu {
        id: quickPanel
        anchors.fill: parent
        streaming: true
        onCloseRequested: streamMenuWindow.closeRequested()
        onDisconnectRequested: {
            if (Chiaki.session) Chiaki.window.close();
            else streamMenuWindow.mainViewRequested();
        }
        onStopRequested: sleep => { streamMenuWindow.closeRequested(); Chiaki.stopSession(sleep); }
        onDisplaySettingsRequested: streamMenuWindow.displaySettingsRequested()
        onPlaceboSettingsRequested: streamMenuWindow.placeboSettingsRequested()
    }
}