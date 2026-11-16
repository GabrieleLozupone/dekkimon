import QtQuick
import QtQuick.Controls
import org.streetpea.chiaking

// Color & HDR: display target (always applied while streaming) plus tone/gamut mapping and
// peak detection. Same settings as before, presented with PortalSettings.
DialogView {
    id: dialog
    property real gridHeight: 2000
    title: qsTr("Color & HDR")
    chrome: false
    buttonVisible: false

    PortalSettings {
        objectName: "colorHdrSettings"
        readonly property PortalSettingsModel model: PortalSettingsModel {}
        title: dialog.title
        items: model.colorHdrPage()
        onCloseRequested: dialog.close()
    }
}
