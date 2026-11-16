import QtQuick
import QtQuick.Controls
import org.streetpea.chiaking

// Picture settings (libplacebo). Presets first, expert parameters on "Advanced" pages.
DialogView {
    id: dialog
    property string options_url: ""
    title: qsTr("Picture settings")
    chrome: false
    buttonVisible: false

    PortalSettings {
        objectName: "pictureSettings"
        readonly property PortalSettingsModel model: PortalSettingsModel {}
        title: dialog.title
        items: model.picturePage(dialog)
        onCloseRequested: dialog.close()
    }
}
