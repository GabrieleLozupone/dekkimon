import QtQuick
import QtQuick.Controls

import org.streetpea.chiaking

// Remap the buttons of the selected controller. Same backend flow as before
// (controllerMappingSelectButton → controllerMappingButtonSelected → updateButton, then
// controllerMappingApply), presented as a Portal settings page. Every DualSense button can
// take two physical buttons ("main" and "extra"), as in the old grid.
DialogView {
    id: dialog
    property bool finalClosing: false
    property bool quitButtonMapping: true
    // Button list captured once, so editing a mapping does not rebuild (and refocus) the page.
    property var buttons: []
    title: Chiaki.currentControllerType ? qsTr("Remap %1").arg(Chiaki.currentControllerType) : qsTr("Remap controller")
    chrome: false
    buttonVisible: false
    Component.onCompleted: buttons = (Chiaki.currentControllerMapping || []).map(b => ({ name: b.buttonName, value: b.buttonValue }))
    Component.onDestruction: {
        if(Chiaki.controllerMappingInProgress)
        {
            finalClosing = true;
            Chiaki.controllerMappingButtonQuit();
            Chiaki.controllerMappingQuit();
        }
    }

    function physical(value, slot) {
        const list = Chiaki.currentControllerMapping || [];
        for (const b of list)
            if (b.buttonValue === value)
                return b.physicalButton && b.physicalButton.length > slot ? b.physicalButton[slot] : "";
        return "";
    }
    function summary(value) {
        const parts = [physical(value, 0), physical(value, 1)].filter(p => !!p);
        return parts.length ? parts.join(" · ") : qsTr("Not set");
    }
    function capture(b, slot) {
        captureCard.buttonValue = b.value;
        captureCard.buttonIndex = slot;
        captureCard.title = slot === 0 ? qsTr("Main button for %1").arg(b.name) : qsTr("Extra button for %1").arg(b.name);
        captureCard.open();
    }

    PortalSettings {
        title: dialog.title
        note: qsTr("Choose a button, then press the button on your controller to use for it. Save to keep the changes.")
        items: {
            let list = [
                { type: "toggle", label: qsTr("Map sticks and triggers too"), detail: qsTr("Also allow remapping the analog sticks and L2/R2."),
                  get: () => Chiaki.enableAnalogStickMapping, set: v => Chiaki.enableAnalogStickMapping = v },
                { type: "action", label: qsTr("Save mapping"), icon: "check",
                  enabled: () => Chiaki.controllerMappingAltered,
                  run: () => { Chiaki.controllerMappingApply(); Chiaki.controllerMappingQuit(); } },
                { type: "header", label: qsTr("Buttons") }
            ];
            for (const b of dialog.buttons) {
                list.push({ type: "page", label: b.name, value: () => dialog.summary(b.value),
                            items: () => [
                                { type: "action", label: qsTr("Main button"), value: () => dialog.physical(b.value, 0) || qsTr("Not set"),
                                  run: () => dialog.capture(b, 0) },
                                { type: "action", label: qsTr("Extra button"), detail: qsTr("Optional second button with the same function."),
                                  value: () => dialog.physical(b.value, 1) || qsTr("Not set"),
                                  run: () => dialog.capture(b, 1) }
                            ] });
            }
            return list;
        }
        onCloseRequested: dialog.close()

        PortalMessageDialog {
            id: captureCard
            property int buttonValue
            property int buttonIndex
            text: qsTr("Press the button on your %1 that should do this.").arg(Chiaki.currentControllerType || qsTr("controller"))
            buttonText: qsTr("Cancel")
            // The next controller press is the answer; it must not operate the card.
            captureKeys: true
            closePolicy: Popup.CloseOnPressOutside
            onOpened: Chiaki.controllerMappingSelectButton()
            onClosed: {
                if (dialog.quitButtonMapping)
                    Chiaki.controllerMappingButtonQuit();
                else
                    dialog.quitButtonMapping = true;
            }
        }

        Connections {
            target: Chiaki

            function onControllerMappingInProgressChanged()
            {
                if(!Chiaki.controllerMappingInProgress && !dialog.finalClosing)
                    dialog.close();
            }

            function onControllerMappingButtonSelected(pressedButton, chiaki_button_value, chiaki_button_name)
            {
                Chiaki.updateButton(captureCard.buttonValue, pressedButton, captureCard.buttonIndex);
                dialog.quitButtonMapping = false;
                captureCard.close();
            }
        }
    }
}
