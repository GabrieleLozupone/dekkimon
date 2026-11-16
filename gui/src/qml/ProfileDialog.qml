import QtQuick
import QtQuick.Controls

import org.streetpea.chiaking

// Settings profiles as a Portal settings page: switch, create, delete. Chiaki.settings.profiles
// lists "default" (stored as an empty currentProfile) and a "create new profile" entry.
DialogView {
    id: dialog
    title: qsTr("Profiles")
    chrome: false
    buttonVisible: false
    property string newName: ""
    readonly property string current: Chiaki.settings.currentProfile
    readonly property var named: (Chiaki.settings.profiles || []).filter(p => p !== "create new profile")

    function label(p) { return p === "default" ? qsTr("Default") : p; }
    function isCurrent(p) { return p === "default" ? !current : p === current; }
    function switchTo(p) {
        Chiaki.settings.currentProfile = p === "default" ? "" : p;
        stack.pop();
    }

    PortalSettings {
        title: dialog.title
        note: qsTr("Each profile keeps its own settings, consoles and sign-in.")
        items: {
            let list = [{ type: "header", label: qsTr("Switch profile") }];
            for (const p of dialog.named) {
                list.push({ type: "action", label: dialog.label(p), icon: "settings",
                            value: () => dialog.isCurrent(p) ? qsTr("Current") : "",
                            enabled: () => !dialog.isCurrent(p),
                            run: () => dialog.switchTo(p) });
            }
            list.push({ type: "header", label: qsTr("New profile") });
            list.push({ type: "text", label: qsTr("Name"), placeholder: qsTr("e.g. Living room"),
                        get: () => dialog.newName, set: v => dialog.newName = v.trim() });
            list.push({ type: "action", label: qsTr("Create and switch"), icon: "plus",
                        enabled: () => !!dialog.newName && dialog.named.indexOf(dialog.newName) < 0,
                        run: () => dialog.switchTo(dialog.newName) });
            const deletable = dialog.named.filter(p => p !== "default" && !dialog.isCurrent(p));
            if (deletable.length) {
                list.push({ type: "header", label: qsTr("Delete") });
                for (const p of deletable) {
                    list.push({ type: "action", label: qsTr("Delete “%1”").arg(p),
                                run: () => root.showConfirmDialog(qsTr("Delete profile"),
                                    qsTr("Delete the profile “%1” and all its settings?").arg(p),
                                    () => Chiaki.settings.deleteProfile(p)) });
                }
            }
            return list;
        }
        onCloseRequested: dialog.close()
    }
}
