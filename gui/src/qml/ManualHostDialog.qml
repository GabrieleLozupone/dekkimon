import QtQuick
import QtQuick.Controls

import org.streetpea.chiaking

// Add a console by address. Same behaviour as before (Chiaki.addManualHost with the chosen
// paired console, or "register on first connection"), presented as a Portal settings page.
DialogView {
    id: dialog
    title: qsTr("Add a console")
    chrome: false
    buttonVisible: false
    property string address: ""
    // Index into pairedOptions; 0 = first paired console (or "register on first connection").
    property int pairedChoice: 0
    readonly property var hosts: Chiaki.settings.registeredHosts
    readonly property var pairedOptions: {
        let m = [];
        for (let i = 0; i < hosts.length; ++i) {
            const h = hosts[i];
            m.push({ label: h.name, detail: Chiaki.settings.streamerMode ? "" : h.mac, index: i });
        }
        m.push({ label: qsTr("Register on first connection"),
                 detail: qsTr("Pair the console the first time you connect to it."), index: hosts.length });
        return m;
    }

    PortalSettings {
        title: dialog.title
        note: qsTr("Use this when the console is not found automatically, e.g. on another network.")
        items: [
            { type: "text", label: qsTr("Console address"), detail: qsTr("IP address or hostname."),
              placeholder: "192.168.0.10", secret: () => Chiaki.settings.streamerMode,
              get: () => dialog.address, set: v => dialog.address = v.trim() },
            { type: "choice", label: qsTr("Paired console"), detail: qsTr("Which pairing to use for this address."),
              options: dialog.pairedOptions, get: () => dialog.pairedChoice, set: i => dialog.pairedChoice = i },
            { type: "action", label: qsTr("Add console"), icon: "plus",
              enabled: () => !!dialog.address,
              run: () => {
                  Chiaki.addManualHost(dialog.pairedOptions[dialog.pairedChoice].index, dialog.address);
                  dialog.close();
              } }
        ]
        onCloseRequested: dialog.close()
    }
}
