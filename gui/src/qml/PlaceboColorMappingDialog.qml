import QtQuick
import QtQuick.Controls
import org.streetpea.chiaking

// Custom tone & gamut mapping. Normally reached as a page inside Color & HDR or Picture
// settings; kept as its own dialog for root.showPlaceboColorMappingDialog().
DialogView {
    enum GamutMappingFunction {
        Clip,
        Perceptual,
        SoftClip,
        Relative,
        Saturation,
        Absolute,
        Desaturate,
        Darken,
        Highlight,
        Linear
    }
    enum ToneMappingFunction {
        Clip,
        Spline,
        St209440,
        St209410,
        Bt2390,
        Bt2446a,
        Reinhard,
        Mobius,
        Hable,
        Gamma,
        Linear,
        LinearLight
    }
    id: dialog
    title: qsTr("Tone & gamut mapping")
    chrome: false
    buttonVisible: false

    PortalSettings {
        objectName: "colorMappingSettings"
        readonly property PortalSettingsModel model: PortalSettingsModel {}
        title: dialog.title
        items: model.colorMappingPage()
        onCloseRequested: dialog.close()
    }
}
