import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

import org.streetpea.chiaking

// Remote connection over PSN (and PSN auto-registration). Before the stream session exists the
// console has to be linked through PSN, which can take several seconds. Shows the same Portal
// connection screen as StreamView (PortalConnectOverlay, same geometry), so the hand-over to
// StreamView once the session starts is a seamless cross-fade.
Rectangle {
    id: view
    property bool allowClose: false
    property bool cancelling: false
    property bool textVisible: true
    property bool registOnly: false
    property string statusText: qsTr("Connecting over the internet")
    property list<Item> restoreFocusItems
    color: "#080812"

    function stop() {
        if (!allowClose)
            return;
        allowClose = false;
        cancelling = true;
        statusText = qsTr("Cancelling…");
        Chiaki.psnCancel(false);
    }

    function grabInput(item) {
        Chiaki.window.grabInput();
        restoreFocusItems.push(Window.window.activeFocusItem);
        if (item)
            item.forceActiveFocus(Qt.TabFocusReason);
    }

    function releaseInput() {
        Chiaki.window.releaseInput();
        let item = restoreFocusItems.pop();
        if (item && item.visible)
            item.forceActiveFocus(Qt.TabFocusReason);
    }

    Keys.onEscapePressed: view.stop()

    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: view.stop()
    }

    MouseArea {
        anchors.fill: parent
        enabled: view.allowClose
        acceptedButtons: Qt.RightButton
        onClicked: view.stop()
    }

    PortalConnectOverlay {
        id: overlay
        objectName: "psnConnectOverlay"
        anchors.fill: parent
        consoleName: typeof root !== "undefined" && root.portalConsoleName && !view.registOnly ? root.portalConsoleName : ""
        statusText: view.statusText
        streamReady: false
        running: view.visible && !errorBox.visible
        titleOpacity: errorBox.visible ? 0 : 1
    }

    // Error after a failed session start, in place of the connection title.
    Column {
        id: errorBox
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: overlay.compact ? 36 : 48
        anchors.topMargin: view.height * 0.17
        width: view.width * 0.6
        spacing: 10
        visible: errorTitleLabel.text !== ""
        Label {
            id: errorTitleLabel
            width: parent.width
            color: "#f5f4fb"
            font.pixelSize: overlay.compact ? 26 : 36
            font.weight: Font.Light
            wrapMode: Text.Wrap
            onVisibleChanged: {
                if (visible) {
                    view.textVisible = false
                    view.allowClose = false
                    view.grabInput(errorTitleLabel)
                }
            }
            Keys.onReturnPressed: root.showMainView()
            Keys.onEscapePressed: root.showMainView()
        }
        Label {
            id: errorTextLabel
            width: parent.width
            color: "#a9a5ba"
            font.pixelSize: overlay.compact ? 15 : 18
            wrapMode: Text.Wrap
        }
    }

    Label {
        id: closeMessageLabel
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: view.width < 800 ? 32 : 64
            bottomMargin: 36
        }
        font.pixelSize: 15
        color: "#a9a5ba"
        opacity: (view.textVisible && view.allowClose && !view.cancelling) ? 1.0 : 0.0
        visible: opacity
        Behavior on opacity { NumberAnimation { duration: 250 } }
        text: {
            var typeString = view.registOnly ? qsTr("automatic registration") : qsTr("remote connection")
            qsTr("Press %1 to cancel %2").arg(Chiaki.controllers.length ? (root.controllerButton("circle").includes("deck") ? "B" : "Circle") : "escape or right-click").arg(typeString)
        }
    }

    Timer {
        id: closeTimer
        interval: 1500
        running: true
        onTriggered: view.allowClose = true
    }

    Timer {
        id: failTimer
        interval: 2000
        running: false
        onTriggered: root.showMainView()
    }

    Dialog {
        id: sessionPinDialog
        parent: Overlay.overlay
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        title: qsTr("Console Login PIN")
        modal: true
        closePolicy: Popup.NoAutoClose
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAboutToShow: {
            standardButton(Dialog.Ok).enabled = Qt.binding(function() {
                return pinField.acceptableInput;
            });
            pinField.text = "";
            view.textVisible = false
            view.grabInput(pinField);
        }
        onClosed: {
            view.textVisible = true
            view.releaseInput()
        }
        onAccepted: Chiaki.enterPin(pinField.text)
        onRejected: Chiaki.stopSession(false)
        Material.roundedScale: Material.MediumScale

        PortalPinPad {
            id: pinField
            implicitWidth: Math.min(view.width - 80, 460)
            implicitHeight: Math.min(view.height - 180, 360)
            onAccepted: sessionPinDialog.accept()
            onCancelled: sessionPinDialog.reject()
        }
    }

    Connections {
        target: Chiaki

        function onConnectStateChanged()
        {
            switch(Chiaki.connectState)
            {
                case Chiaki.PsnConnectState.LinkingConsole:
                    view.statusText = view.registOnly ? qsTr("Registering the console with Dekkimon") : qsTr("Reaching the console through PSN")
                    view.allowClose = false
                    break
                case Chiaki.PsnConnectState.RegisteringConsole:
                    view.registOnly = true;
                    break
                case Chiaki.PsnConnectState.RegistrationFinished:
                    view.statusText = qsTr("Console registered")
                    failTimer.restart()
                    break
                case Chiaki.PsnConnectState.DataConnectionStart:
                    view.statusText = qsTr("Console found, opening the connection")
                    view.allowClose = true
                    break
                case Chiaki.PsnConnectState.DataConnectionFinished:
                    view.statusText = qsTr("Starting Remote Play")
                    view.allowClose = false
                    break
                case Chiaki.PsnConnectState.ConnectFailed:
                    if(!view.cancelling)
                        view.statusText = qsTr("Connection over PSN failed")
                    failTimer.running = true
                    break
                case Chiaki.PsnConnectState.ConnectFailedStart:
                    if(!view.cancelling)
                        view.statusText = qsTr("PSN couldn't reach the console. Please try again")
                    failTimer.running = true
                    break
                case Chiaki.PsnConnectState.ConnectFailedConsoleUnreachable:
                    if(!view.cancelling)
                        view.statusText = qsTr("Couldn't contact the console over this network (likely an unsupported network type)")
                    failTimer.running = true
                    break
                case Chiaki.PsnConnectState.WaitingForInternet:
                    view.statusText = qsTr("Waiting for an internet connection")
                    break
            }
        }

        function onSessionChanged()
        {
            if (!Chiaki.session) {
                if (errorTitleLabel.text)
                    failTimer.start();
                else if(!failTimer.running)
                    root.showMainView();
            }
        }

        function onSessionError(title, text)
        {
            errorTitleLabel.text = title;
            errorTextLabel.text = text;
            closeTimer.start();
        }

        function onSessionPinDialogRequested()
        {
            if (sessionPinDialog.opened)
                return;
            sessionPinDialog.open();
        }
    }
}
