import QtQuick
import QtQuick.Controls
import org.streetpea.chiaking

DialogView {
    id: pinDialog
    property var consoleIndex
    title: qsTr("Console passcode")
    header: qsTr("Enter your four-digit Remote Play PIN. A selects a digit; X deletes.")
    buttonText: qsTr("Save")
    buttonEnabled: pin.acceptableInput
    onAccepted: {
        Chiaki.setConsolePin(consoleIndex, pin.text);
        pin.text = "";
        close();
    }
    Item {
        PortalPinPad {
            id: pin
            anchors.centerIn: parent
            width: Math.min(parent.width, 480)
            height: Math.min(parent.height, 380)
            onAccepted: pinDialog.accepted()
            onCancelled: pinDialog.close()
        }
    }
}