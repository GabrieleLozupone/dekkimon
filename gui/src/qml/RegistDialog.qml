import QtQuick
import QtQuick.Controls

import org.streetpea.chiaking

// Pair (register) a console. Same backend call as before (Chiaki.registerHost with the console
// generation as `target`), presented as a Portal settings page with a progress card. The PSN
// account ID comes from the phone sign-in when available.
DialogView {
    id: dialog
    property bool ps5: true
    property string host: ""
    property string onlineId: ""
    property string accountId: Chiaki.settings.psnAccountId
    property string pin: ""
    property string consolePin: ""
    // Console generations, newest first; `target` is what registerHost expects.
    readonly property var consoles: [
        { label: "PS5", detail: "", target: 1000100 },
        { label: qsTr("PS4, system software 8.0 or later"), detail: "", target: 1000 },
        { label: qsTr("PS4, system software 7.x"), detail: "", target: 900 },
        { label: qsTr("PS4, system software before 7.0"), detail: qsTr("Uses your PSN online ID instead of the account ID."), target: 800 }
    ]
    property int consoleChoice: ps5 ? 0 : 1
    readonly property bool needsOnlineId: consoles[consoleChoice].target === 800
    readonly property bool broadcast: host.trim() === "255.255.255.255"
    readonly property bool ready: !!host.trim() && /^[0-9]{8}$/.test(pin) && /^([0-9]{4})?$/.test(consolePin)
                                  && (needsOnlineId ? !!onlineId : !!accountId)
    title: qsTr("Pair your PlayStation")
    chrome: false
    buttonVisible: false

    function pair() {
        const psnId = needsOnlineId ? onlineId : accountId;
        progress.log = "";
        progress.busy = true;
        progress.title = qsTr("Pairing your PlayStation");
        const ok = Chiaki.registerHost(host.trim(), psnId, pin, consolePin, broadcast, consoles[consoleChoice].target, function(msg, ok, done) {
            progress.append(msg);
            if (done) {
                progress.busy = false;
                progress.title = ok ? qsTr("PlayStation paired") : qsTr("Pairing did not finish");
            }
        });
        if (ok)
            progress.open();
    }

    PortalSettings {
        title: dialog.title
        note: qsTr("On your console open Settings › System › Remote Play › Pair Device, then enter the 8-digit code shown there.")
        items: [
            { type: "text", label: qsTr("Console address"),
              detail: dialog.broadcast ? qsTr("Searching your network for the console.") : "",
              secret: () => Chiaki.settings.streamerMode,
              get: () => dialog.host, set: v => dialog.host = v.trim() },
            { type: "choice", label: qsTr("Console"), options: dialog.consoles,
              get: () => dialog.consoleChoice, set: i => dialog.consoleChoice = i },
            { type: "text", label: qsTr("Pairing code"), detail: qsTr("8 digits, shown on the console."),
              placeholder: "12345678", inputHint: Qt.ImhDigitsOnly, maxLength: 8,
              secret: () => Chiaki.settings.streamerMode,
              get: () => dialog.pin, set: v => dialog.pin = v.trim() },
            { type: "text", label: qsTr("Console PIN"), detail: qsTr("Optional: the 4-digit PIN to start Remote Play, if you set one."),
              inputHint: Qt.ImhDigitsOnly, maxLength: 4, secret: () => Chiaki.settings.streamerMode,
              get: () => dialog.consolePin, set: v => dialog.consolePin = v.trim() },
            { type: "header", label: qsTr("PlayStation Network") },
            { type: "action", label: qsTr("Sign in with your phone"), detail: qsTr("Fills in your account automatically."), icon: "globe",
              visible: () => !dialog.needsOnlineId && !Chiaki.settings.psnAccountId,
              run: () => root.showPSNTokenDialog(false) },
            { type: "text", label: qsTr("Account ID"), detail: qsTr("Filled in after signing in."),
              visible: () => !dialog.needsOnlineId, secret: () => Chiaki.settings.streamerMode,
              get: () => dialog.accountId, set: v => dialog.accountId = v.trim() },
            { type: "text", label: qsTr("Online ID"), detail: qsTr("Your PSN name, case-sensitive."),
              visible: () => dialog.needsOnlineId, secret: () => Chiaki.settings.streamerMode,
              get: () => dialog.onlineId, set: v => dialog.onlineId = v.trim() },
            { type: "action", label: qsTr("Pair console"), icon: "check",
              enabled: () => dialog.ready, run: () => dialog.pair() }
        ]
        onCloseRequested: dialog.close()

        PortalProgressDialog {
            id: progress
            onFinished: stack.pop()
        }
    }
}
