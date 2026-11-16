import QtQuick
import QtQuick.Controls

import org.streetpea.chiaking

// Add this app to Steam as a non-Steam game. Same backend call as before
// (Chiaki.createSteamShortcut), presented as a Portal settings page with a progress card.
DialogView {
    id: dialog
    property bool opening: false
    property bool succeeded: false
    property bool fromReminder
    property string gameName: Chiaki.settings.currentProfile ? "Dekkimon " + Chiaki.settings.currentProfile : "Dekkimon"
    property string launchOptions: Chiaki.settings.currentProfile ? "--profile=" + Chiaki.settings.currentProfile : ""
    property string steamBasePath: ""
    title: qsTr("Add to Steam")
    chrome: false
    buttonVisible: false

    function close() {
        root.closeDialog();
        if (dialog.fromReminder && Chiaki.settings.remotePlayAsk) {
            if (!Chiaki.settings.psnRefreshToken || !Chiaki.settings.psnAuthToken || !Chiaki.settings.psnAuthTokenExpiry || !Chiaki.settings.psnAccountId)
                root.showRemindDialog(qsTr("Remote Play via PSN"), qsTr("Sign in to PlayStation Network to register consoles automatically and to play away from home without port forwarding.") + "\n\n" + qsTr("You can do this later in Settings › Remote access."), true, () => root.showPSNTokenDialog(false));
            else
                Chiaki.settings.remotePlayAsk = false;
        }
    }

    function create() {
        opening = true;
        progress.log = "";
        progress.busy = true;
        progress.title = qsTr("Adding “%1” to Steam").arg(gameName);
        progress.open();
        Chiaki.createSteamShortcut(gameName, launchOptions, function(msg, ok, done) {
            if (ok) {
                succeeded = true;
                Chiaki.settings.addSteamShortcutAsk = false;
            }
            progress.append(msg);
            if (done) {
                progress.busy = false;
                opening = false;
                if (succeeded) {
                    progress.title = qsTr("Added to Steam");
                    progress.append("\n" + qsTr("Restart Steam to see “%1” in your library.").arg(gameName));
                }
            }
        }, steamBasePath);
    }

    PortalSettings {
        title: dialog.title
        note: qsTr("Adds this app to your Steam library as a non-Steam game, so you can start it from Gaming Mode.")
        items: [
            { type: "text", label: qsTr("Name in Steam"), get: () => dialog.gameName, set: v => dialog.gameName = v.trim() },
            { type: "text", label: qsTr("Launch options"), detail: qsTr("Optional."), placeholder: "--profile=…",
              get: () => dialog.launchOptions, set: v => dialog.launchOptions = v.trim() },
            { type: "action", label: qsTr("Steam folder"), detail: qsTr("Only needed if Steam is installed in an unusual place."),
              value: () => dialog.steamBasePath || qsTr("Automatic"),
              run: () => dialog.steamBasePath = Chiaki.settings.chooseSteamBasePath() || dialog.steamBasePath },
            { type: "action", label: qsTr("Add to Steam"), icon: "plus",
              enabled: () => !!dialog.gameName && !dialog.opening,
              run: () => dialog.create() }
        ]
        onCloseRequested: dialog.close()

        PortalProgressDialog {
            id: progress
            onFinished: if (dialog.succeeded) dialog.close()
        }
    }
}
