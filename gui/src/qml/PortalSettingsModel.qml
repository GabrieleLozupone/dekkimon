import QtQuick
import org.streetpea.chiaking

// Descriptors for the Portal-style stream settings pages (rendered by PortalSettings.qml).
// Every getter/setter reads and writes the same Chiaki.settings property, with the same
// values, as the previous DisplaySettingsDialog / PlaceboSettingsDialog /
// PlaceboColorMappingDialog controls did. Only grouping, wording and order are new.
QtObject {
    id: m

    // ---- helpers -------------------------------------------------------------------------
    function slider(prop, label, detail, from, to, step, decimals, def, visible, unit) {
        return { type: "slider", label: label, detail: detail, from: from, to: to, step: step,
                 decimals: decimals, def: def, unit: unit || "", visible: visible,
                 get: () => Chiaki.settings[prop], set: v => Chiaki.settings[prop] = v };
    }
    function toggle(prop, label, detail, visible) {
        return { type: "toggle", label: label, detail: detail, visible: visible,
                 get: () => !!Chiaki.settings[prop], set: v => Chiaki.settings[prop] = v };
    }
    function choice(prop, label, detail, options, visible, note) {
        return { type: "choice", label: label, detail: detail, options: options, visible: visible, note: note,
                 get: () => Chiaki.settings[prop], set: i => Chiaki.settings[prop] = i };
    }
    function header(label, visible) { return { type: "header", label: label, visible: visible }; }
    function note(label, visible) { return { type: "note", label: label, visible: visible }; }
    function opts(list) { return list.map(o => Array.isArray(o) ? { label: o[0], detail: o[1] || "" } : { label: o, detail: "" }); }
    // "Off / preset / Custom" collapsed from an enabled flag plus a preset index, where the
    // preset index 0 means "Custom" (as in the old dialogs).
    function presetChoice(enabledProp, presetProp, label, detail, presets, note) {
        // presets: [{ label, detail, preset }]; option 0 is Off, the last one Custom (preset 0).
        const options = [{ label: qsTr("Off"), detail: "" }].concat(presets.map(p => ({ label: p.label, detail: p.detail || "" })))
            .concat([{ label: qsTr("Custom"), detail: qsTr("Tune every value yourself on the next page.") }]);
        return {
            type: "choice", label: label, detail: detail, options: options, note: note,
            get: () => {
                if (!Chiaki.settings[enabledProp]) return 0;
                const p = Chiaki.settings[presetProp];
                const i = presets.findIndex(x => x.preset === p);
                return i >= 0 ? i + 1 : options.length - 1;
            },
            set: i => {
                if (i === 0) { Chiaki.settings[enabledProp] = false; return; }
                Chiaki.settings[enabledProp] = true;
                Chiaki.settings[presetProp] = i === options.length - 1 ? 0 : presets[i - 1].preset;
            }
        };
    }
    function isCustom(enabledProp, presetProp) {
        return () => !!Chiaki.settings[enabledProp] && Chiaki.settings[presetProp] === 0;
    }

    // ---- rendering quality (same writes as the quick menu) -------------------------------
    readonly property var presetValues: [ChiakiWindow.VideoPreset.Fast, ChiakiWindow.VideoPreset.Default,
        ChiakiWindow.VideoPreset.HighQuality, ChiakiWindow.VideoPreset.HighQualitySpatial,
        ChiakiWindow.VideoPreset.HighQualityAdvancedSpatial, ChiakiWindow.VideoPreset.Custom]
    function renderingQuality() {
        return {
            type: "choice", icon: "quality", label: qsTr("Rendering quality"),
            detail: qsTr("How this device scales and filters the picture. Does not change the stream bitrate."),
            options: opts([[qsTr("Fast"), qsTr("Lowest GPU load and battery use.")],
                           [qsTr("Default"), qsTr("Balanced scaling.")],
                           [qsTr("High quality"), qsTr("Sharper scaling. Recommended on Steam Deck OLED.")],
                           [qsTr("HQ + spatial"), qsTr("Adds spatial upscaling.")],
                           [qsTr("HQ + advanced spatial"), qsTr("Best upscaling, highest GPU load.")],
                           [qsTr("Custom"), qsTr("Uses the picture settings on this page.")]]),
            get: () => m.presetValues.indexOf(Chiaki.window.videoPreset),
            set: i => { Chiaki.window.videoPreset = m.presetValues[i]; Chiaki.settings.videoPreset = m.presetValues[i]; }
        };
    }
    function customActive() { return Chiaki.window.videoPreset === ChiakiWindow.VideoPreset.Custom; }
    function customOnlyNote() {
        return note(qsTr("These settings are used only when Rendering quality is Custom."), () => !m.customActive());
    }

    // ---- Color & HDR -----------------------------------------------------------------------
    function colorHdrPage() {
        return [
            header(qsTr("HDR brightness")),
            {
                type: "choice", icon: "hdr", label: qsTr("Peak brightness"),
                detail: qsTr("The brightest highlight the picture is mapped to."),
                options: opts([[qsTr("Automatic"), qsTr("Use what the display and compositor report.")],
                               [qsTr("Set manually"), qsTr("Pick a value in nits. Steam Deck OLED reaches 1000 nits in HDR.")]]),
                get: () => Chiaki.settings.displayTargetPeak == 0 ? 0 : 1,
                set: i => Chiaki.settings.displayTargetPeak = i === 0 ? 0 : (Chiaki.settings.displayTargetPeak || 1000)
            },
            slider("displayTargetPeak", qsTr("Peak brightness value"), "", 10, 10000, 10, 0, 1000,
                   () => Chiaki.settings.displayTargetPeak != 0, qsTr("nits")),
            {
                type: "choice", label: qsTr("Contrast"),
                detail: qsTr("How dark the display's black level is."),
                options: opts([[qsTr("Automatic"), qsTr("Use what the display reports.")],
                               [qsTr("Infinite"), qsTr("True black, as on OLED screens.")],
                               [qsTr("Set manually"), qsTr("Pick a contrast ratio.")]]),
                get: () => Chiaki.settings.displayTargetContrast == -1 ? 1 : Chiaki.settings.displayTargetContrast == 0 ? 0 : 2,
                set: i => Chiaki.settings.displayTargetContrast = i === 0 ? 0 : i === 1 ? -1
                    : (Chiaki.settings.displayTargetContrast > 0 ? Chiaki.settings.displayTargetContrast : 1000)
            },
            slider("displayTargetContrast", qsTr("Contrast ratio"), qsTr("Shown as N:1."), 10, 1000000, 1000, 0, 1000,
                   () => Chiaki.settings.displayTargetContrast > 0),
            header(qsTr("Tone mapping")),
            note(qsTr("Tone mapping fits the console's HDR picture to this screen. It applies when Rendering quality is Custom.")),
            presetChoice("placeboColorMappingEnabled", "placeboColorMappingPreset", qsTr("Tone & gamut mapping"),
                         qsTr("How bright and saturated colours are squeezed into this display."),
                         [{ label: qsTr("Default"), detail: qsTr("libplacebo's standard mapping."), preset: 1 },
                          { label: qsTr("High quality"), detail: qsTr("Smoother highlights, slightly more GPU work."), preset: 2 }]),
            { type: "page", label: qsTr("Custom tone & gamut mapping"), detail: qsTr("Curves, knees and lookup tables."),
              visible: isCustom("placeboColorMappingEnabled", "placeboColorMappingPreset"), items: () => m.colorMappingPage() },
            presetChoice("placeboPeakDetectionEnabled", "placeboPeakDetectionPreset", qsTr("HDR peak detection"),
                         qsTr("Measures each frame's brightness so highlights are not clipped."),
                         [{ label: qsTr("Default"), preset: 1 },
                          { label: qsTr("High quality"), detail: qsTr("More accurate, slightly more GPU work."), preset: 2 }]),
            { type: "page", label: qsTr("Custom peak detection"), detail: qsTr("Smoothing and scene thresholds."),
              visible: isCustom("placeboPeakDetectionEnabled", "placeboPeakDetectionPreset"), items: () => m.peakDetectionPage() },
            header(qsTr("Advanced")),
            { type: "page", icon: "settings", label: qsTr("Display colour space"),
              detail: qsTr("Override the colour primaries and transfer curve. Leave on Automatic unless colours look wrong."),
              value: () => (Chiaki.settings.displayTargetPrim == 0 && Chiaki.settings.displayTargetTrc == 0) ? qsTr("Automatic") : qsTr("Overridden"),
              items: () => m.colorSpacePage() }
        ];
    }
    function colorSpacePage() {
        return [
            choice("displayTargetPrim", qsTr("Colour primaries"), qsTr("The colour gamut of the display."),
                   opts([[qsTr("Automatic"), qsTr("Recommended.")], qsTr("ITU-R Rec. BT.601 NTSC (Standard Gamut)"), qsTr("ITU-R Rec. BT.601 PAL (Standard Gamut)"),
                         qsTr("ITU-R Rec. BT.709 (Standard Gamut)"), qsTr("ITU-R Rec. BT.470 M (Standard Gamut)"), qsTr("EBU Tech. 3213-E (Standard Gamut)"),
                         qsTr("ITU-R Rec. BT.2020 (Wide Gamut)"), qsTr("Apple RGB (Wide Gamut)"), qsTr("Adobe RGB (Wide Gamut)"), qsTr("ProPhoto RGB (Wide Gamut)"),
                         qsTr("CIE 1931 RGB primaries (Wide Gamut)"), qsTr("DCI-P3 (Wide Gamut)"), qsTr("DCI-P3 with D65 white point (Wide Gamut)"),
                         qsTr("Panasonic V-Gamut (Wide Gamut)"), qsTr("Sony S-Gamut (Wide Gamut)"), qsTr("Traditional film primaries with Illuminant C (Wide Gamut)"),
                         qsTr("ACES Primaries #0 (Wide Gamut)"), qsTr("ACES Primaries #1 (Wide Gamut)")])),
            choice("displayTargetTrc", qsTr("Transfer curve"), qsTr("How brightness values are encoded for the display."),
                   opts([[qsTr("Automatic"), qsTr("Recommended.")], qsTr("ITU-R Rec. BT.1886 (SDR)"), qsTr("IEC 61966-2-4 sRGB (SDR)"), qsTr("Linear light content (SDR)"),
                         qsTr("Pure power gamma 1.8 (SDR)"), qsTr("Pure power gamma 2.0 (SDR)"), qsTr("Pure power gamma 2.2 (SDR)"), qsTr("Pure power gamma 2.4 (SDR)"),
                         qsTr("Pure power gamma 2.6 (SDR)"), qsTr("Pure power gamma 2.8 (SDR)"), qsTr("ProPhoto RGB (SDR)"), qsTr("Digital Cinema Distribution Master (SDR)"),
                         qsTr("ITU-R BT.2100 PQ / SMPTE ST2048 (HDR)"), qsTr("ITU-R BT.2100 HLG / ARIB STD-B67 (HDR)"), qsTr("Panasonic V-Log (HDR)"),
                         qsTr("Sony S-Log1 (HDR)"), qsTr("Sony S-Log2 (HDR)")]))
        ];
    }

    // ---- Tone & gamut mapping (custom) ------------------------------------------------------
    function gamut(...f) { return () => f.indexOf(Chiaki.settings.placeboGamutMappingFunction) >= 0; }
    function tone(...f) { return () => f.indexOf(Chiaki.settings.placeboToneMappingFunction) >= 0; }
    function colorMappingPage() {
        // Gamut: 0 Clip, 1 Perceptual, 2 SoftClip, 3 Relative, 4 Saturation, 5 Absolute,
        //        6 Desaturate, 7 Darken, 8 Highlight, 9 Linear
        // Tone:  0 Clip, 1 Spline, 2 ST2094-40, 3 ST2094-10, 4 BT2390, 5 BT2446a, 6 Reinhard,
        //        7 Mobius, 8 Hable, 9 Gamma, 10 Linear, 11 Linear light
        return [
            customOnlyNote(),
            header(qsTr("Gamut mapping")),
            choice("placeboGamutMappingFunction", qsTr("Method"), qsTr("What happens to colours the display cannot show."),
                   opts([[qsTr("Clip"), qsTr("Cut off out-of-range colours. Fastest, can band.")],
                         [qsTr("Perceptual"), qsTr("Compress smoothly, keeping hue. Default.")],
                         [qsTr("Soft clip"), qsTr("Clip with a gentle roll-off near the edge.")],
                         [qsTr("Relative"), qsTr("Colorimetric, relative to the white point.")],
                         [qsTr("Saturation"), qsTr("Keep saturation, may shift hue.")],
                         [qsTr("Absolute"), qsTr("Colorimetric, absolute white point.")],
                         [qsTr("Desaturate"), qsTr("Fade out-of-range colours toward grey.")],
                         [qsTr("Darken"), qsTr("Darken to fit inside the gamut.")],
                         [qsTr("Highlight"), qsTr("Debug: mark out-of-gamut pixels.")],
                         [qsTr("Linear"), qsTr("Scale the whole gamut linearly.")]])),
            slider("placeboGamutMappingPerceptualDeadzone", qsTr("Perceptual deadzone"), qsTr("Colours inside this range are left untouched."), 0, 1, 0.01, 2, 0.30, gamut(1)),
            slider("placeboGamutMappingPerceptualStrength", qsTr("Perceptual strength"), "", 0, 1, 0.01, 2, 0.80, gamut(1)),
            slider("placeboGamutMappingColorimetricGamma", qsTr("Colorimetric gamma"), "", 0, 10, 0.01, 2, 1.80, gamut(3, 5, 7)),
            slider("placeboGamutMappingSoftClipKnee", qsTr("Soft clip knee"), "", 0, 1, 0.01, 2, 0.70, gamut(1, 2)),
            slider("placeboGamutMappingSoftClipDesat", qsTr("Soft clip desaturation"), "", 0, 1, 0.01, 2, 0.35, gamut(2)),
            toggle("placeboGamutMappingGamutExpansionEnabled", qsTr("Gamut expansion"), qsTr("Stretch standard-gamut content to fill a wide-gamut display.")),
            header(qsTr("Tone mapping")),
            choice("placeboToneMappingFunction", qsTr("Curve"), qsTr("How HDR brightness is compressed for this display."),
                   opts([[qsTr("Clip"), qsTr("No curve; highlights clip.")],
                         [qsTr("Spline"), qsTr("Smooth, contrast-preserving. Default.")],
                         [qsTr("ST 2094-40"), qsTr("HDR10+ style dynamic curve.")],
                         [qsTr("ST 2094-10"), qsTr("Dolby Vision style dynamic curve.")],
                         [qsTr("BT.2390"), qsTr("ITU reference roll-off.")],
                         [qsTr("BT.2446a"), qsTr("ITU method for HDR to SDR.")],
                         [qsTr("Reinhard"), qsTr("Simple, soft highlights.")],
                         [qsTr("Mobius"), qsTr("Linear midtones, soft highlights.")],
                         [qsTr("Hable"), qsTr("Filmic curve.")],
                         [qsTr("Gamma"), qsTr("Power-curve roll-off.")],
                         [qsTr("Linear"), qsTr("Scale brightness linearly.")],
                         [qsTr("Linear light"), qsTr("Linear in light, no perceptual weighting.")]])),
            slider("placeboToneMappingKneeAdaptation", qsTr("Knee adaptation"), "", 0, 1, 0.01, 2, 0.40, tone(1, 2, 3)),
            slider("placeboToneMappingKneeMinimum", qsTr("Knee minimum"), "", 0, 0.5, 0.01, 2, 0.10, tone(1, 2, 3)),
            slider("placeboToneMappingKneeMaximum", qsTr("Knee maximum"), "", 0.5, 1, 0.01, 2, 0.80, tone(1, 2, 3)),
            slider("placeboToneMappingKneeDefault", qsTr("Knee default"), "", 0, 1, 0.01, 2, 0.40),
            slider("placeboToneMappingKneeOffset", qsTr("Knee offset"), "", 0.5, 2, 0.01, 2, 1.00, tone(4)),
            slider("placeboToneMappingSlopeTuning", qsTr("Slope tuning"), "", 0, 10, 0.1, 1, 1.5, tone(1)),
            slider("placeboToneMappingSlopeOffset", qsTr("Slope offset"), "", 0, 1, 0.01, 2, 0.20, tone(1)),
            slider("placeboToneMappingSplineContrast", qsTr("Spline contrast"), "", 0, 1.5, 0.01, 2, 0.50, tone(1)),
            slider("placeboToneMappingReinhardContrast", qsTr("Reinhard contrast"), "", 0, 1, 0.01, 2, 0.50, tone(6)),
            slider("placeboToneMappingLinearKnee", qsTr("Linear knee"), "", 0, 1, 0.01, 2, 0.3, tone(7, 9)),
            slider("placeboToneMappingExposure", qsTr("Exposure"), "", 0, 10, 0.1, 1, 1.0, tone(10, 11)),
            toggle("placeboToneMappingInverseToneMappingEnabled", qsTr("Inverse tone mapping"), qsTr("Expand SDR content to HDR brightness.")),
            choice("placeboToneMappingMetadata", qsTr("HDR metadata"), qsTr("Which brightness metadata to trust."),
                   opts([[qsTr("Any"), qsTr("Use whatever is available. Default.")], qsTr("None"), qsTr("HDR10"), qsTr("HDR10+"), qsTr("CIE Y")])),
            slider("placeboToneMappingContrastRecovery", qsTr("Contrast recovery"), qsTr("Restores detail lost in bright areas."), 0, 2, 0.01, 2, 0.30),
            slider("placeboToneMappingContrastSmoothness", qsTr("Contrast smoothness"), "", 1, 32, 0.1, 1, 3.5),
            header(qsTr("Lookup tables (expert)")),
            slider("placeboGamutMappingLut3dSizeI", qsTr("3D LUT size: intensity"), "", 0, 1024, 1, 0, 48),
            slider("placeboGamutMappingLut3dSizeC", qsTr("3D LUT size: chroma"), "", 0, 1024, 1, 0, 32),
            slider("placeboGamutMappingLut3dSizeH", qsTr("3D LUT size: hue"), "", 0, 1024, 1, 0, 256),
            toggle("placeboGamutMappingLut3dTricubicEnabled", qsTr("Tricubic interpolation"), qsTr("Smoother 3D LUT sampling, more GPU work.")),
            slider("placeboToneMappingToneLutSize", qsTr("Tone LUT size"), "", 0, 4096, 1, 0, 256)
        ];
    }
    function peakDetectionPage() {
        return [
            customOnlyNote(),
            slider("placeboPeakDetectionPeakSmoothingPeriod", qsTr("Smoothing period"), qsTr("Frames to average over. Higher is steadier, slower to react."), 0, 1000, 0.1, 1, 20.0),
            slider("placeboPeakDetectionSceneThresholdLow", qsTr("Scene change threshold (low)"), "", 0, 100, 0.1, 1, 1.0),
            slider("placeboPeakDetectionSceneThresholdHigh", qsTr("Scene change threshold (high)"), "", 0, 100, 0.1, 1, 3.0),
            slider("placeboPeakDetectionPeakPercentile", qsTr("Peak percentile"), qsTr("Ignore the brightest pixels above this percentile."), 0, 100, 0.001, 3, 99.995),
            slider("placeboPeakDetectionBlackCutoff", qsTr("Black cutoff"), "", 0, 100, 0.1, 1, 1.0),
            toggle("placeboPeakDetectionAllowDelayedPeak", qsTr("Allow 1-frame delayed peak"), qsTr("Cheaper, but reacts one frame late."))
        ];
    }

    // ---- Picture settings ------------------------------------------------------------------
    readonly property var upscalers: opts([[qsTr("Unset"), qsTr("libplacebo decides.")],
        [qsTr("Nearest"), qsTr("Blocky, no filtering.")], [qsTr("Bilinear"), qsTr("Soft, cheapest filter.")],
        [qsTr("Oversample"), qsTr("Sharp pixel-art style.")], [qsTr("Bicubic"), qsTr("Classic, slightly soft.")],
        [qsTr("Gaussian"), qsTr("Very soft.")], [qsTr("Catmull-Rom"), qsTr("Sharp bicubic.")],
        [qsTr("Lanczos"), qsTr("Sharp, can ring on edges.")], [qsTr("EWA Lanczos"), qsTr("High quality, round kernel.")],
        [qsTr("EWA Lanczos Sharp"), qsTr("High quality and sharper. Default.")], [qsTr("EWA Lanczos Sharpest"), qsTr("Sharpest EWA variant.")],
        [qsTr("AMD FSR"), qsTr("Edge-adaptive spatial upscaling.")],
        [qsTr("FSRCNNX 8"), qsTr("Neural upscaler, lighter.")], [qsTr("FSRCNNX 16"), qsTr("Neural upscaler, heaviest.")]])
    readonly property var downscalers: [qsTr("Unset"), qsTr("Box"), qsTr("Hermite"), qsTr("Bilinear"), qsTr("Bicubic"),
        qsTr("Gaussian"), qsTr("Catmull-Rom"), qsTr("Mitchell"), qsTr("Lanczos")]
    function picturePage(dialog) {
        return [
            renderingQuality(),
            customOnlyNote(),
            header(qsTr("Image")),
            choice("placeboUpscaler", qsTr("Upscaling"), qsTr("How the stream is enlarged to fill the screen."), upscalers),
            presetChoice("placeboDebandEnabled", "placeboDebandPreset", qsTr("Debanding"),
                         qsTr("Smooths colour bands in skies and gradients."),
                         [{ label: qsTr("Default"), detail: qsTr("Recommended."), preset: 1 }]),
            { type: "page", label: qsTr("Custom debanding"), visible: isCustom("placeboDebandEnabled", "placeboDebandPreset"),
              items: () => m.debandPage() },
            presetChoice("placeboColorAdjustmentEnabled", "placeboColorAdjustmentPreset", qsTr("Colour adjustment"),
                         qsTr("Brightness, contrast, saturation, hue, gamma and temperature."),
                         [{ label: qsTr("Neutral"), detail: qsTr("No change to the picture."), preset: 1 }]),
            { type: "page", label: qsTr("Adjust colours"), visible: isCustom("placeboColorAdjustmentEnabled", "placeboColorAdjustmentPreset"),
              items: () => m.colorAdjustmentPage() },
            header(qsTr("HDR")),
            { type: "page", icon: "hdr", label: qsTr("Tone mapping & peak detection"), detail: qsTr("Also available from Color & HDR."),
              items: () => m.colorHdrPage().slice(6, 11) },
            header(qsTr("Advanced")),
            { type: "page", label: qsTr("Scaling details"), detail: qsTr("Per-plane scalers, downscaling and anti-ringing."), items: () => m.scalingPage() },
            { type: "page", label: qsTr("Sigmoidization"), detail: qsTr("Reduces ringing when upscaling."),
              value: () => Chiaki.settings.placeboSigmoidEnabled ? qsTr("On") : qsTr("Off"), items: () => m.sigmoidPage() },
            { type: "page", label: qsTr("Deinterlacing"), detail: qsTr("Only for interlaced video; the PS5 stream is progressive."),
              value: () => Chiaki.settings.placeboDeinterlaceEnabled ? qsTr("On") : qsTr("Off"), items: () => m.deinterlacePage() },
            header(qsTr("Tools")),
            { type: "action", label: qsTr("Export picture settings"), detail: qsTr("Save these settings to a file."),
              run: () => Chiaki.settings.exportPlaceboSettings() },
            { type: "action", label: qsTr("Import picture settings"), detail: qsTr("Load settings from a file."),
              run: () => Chiaki.settings.importPlaceboSettings() },
            { type: "action", label: qsTr("libplacebo documentation"),
              detail: dialog && dialog.options_url ? qsTr("Opened in the browser; the link was copied again.") : qsTr("Opens the options reference and copies its link."),
              run: () => { if (dialog) dialog.options_url = Chiaki.openPlaceboOptionsLink(); else Chiaki.openPlaceboOptionsLink(); } }
        ];
    }
    function debandPage() {
        return [
            customOnlyNote(),
            slider("placeboDebandIterations", qsTr("Iterations"), qsTr("More passes remove more banding."), 0, 16, 1, 0, 1),
            slider("placeboDebandThreshold", qsTr("Threshold"), qsTr("How strong a step counts as banding."), 0, 1000, 0.1, 1, 3.0),
            slider("placeboDebandRadius", qsTr("Radius"), "", 0, 1000, 0.1, 1, 16.0),
            slider("placeboDebandGrain", qsTr("Grain"), qsTr("Noise added to hide remaining bands."), 0, 1000, 0.1, 1, 4.0)
        ];
    }
    function colorAdjustmentPage() {
        return [
            customOnlyNote(),
            slider("placeboColorAdjustmentBrightness", qsTr("Brightness"), "", -1, 1, 0.01, 2, 0.00),
            slider("placeboColorAdjustmentContrast", qsTr("Contrast"), "", 0, 100, 0.1, 1, 1.0),
            slider("placeboColorAdjustmentSaturation", qsTr("Saturation"), "", 0, 100, 0.1, 1, 1.0),
            slider("placeboColorAdjustmentHue", qsTr("Hue"), qsTr("Rotation in radians."), 0, 6.28, 0.01, 2, 0.00),
            slider("placeboColorAdjustmentGamma", qsTr("Gamma"), "", 0, 100, 0.1, 1, 1.0),
            slider("placeboColorAdjustmentTemperature", qsTr("Temperature"), qsTr("Negative is warmer, positive is cooler."), -1.143, 5.286, 0.001, 3, 0.000)
        ];
    }
    function scalingPage() {
        return [
            customOnlyNote(),
            choice("placeboPlaneUpscaler", qsTr("Plane upscaler"), qsTr("Scaler for chroma planes."),
                   [{ label: qsTr("Same as Upscaling"), detail: qsTr("Default.") }].concat(upscalers.slice(1))),
            choice("placeboDownscaler", qsTr("Downscaling"), qsTr("Used when the stream is larger than the screen."),
                   opts(downscalers.map((d, i) => i === 2 ? [d, qsTr("Default.")] : d))),
            choice("placeboPlaneDownscaler", qsTr("Plane downscaler"), "",
                   [{ label: qsTr("Same as Downscaling"), detail: qsTr("Default.") }].concat(opts(downscalers.slice(1)))),
            slider("placeboAntiringingStrength", qsTr("Anti-ringing strength"), qsTr("Reduces halos around sharp edges."), 0, 1, 0.01, 2, 0.00)
        ];
    }
    function sigmoidPage() {
        return [
            customOnlyNote(),
            presetChoice("placeboSigmoidEnabled", "placeboSigmoidPreset", qsTr("Sigmoidization"), "",
                         [{ label: qsTr("Default"), detail: qsTr("Recommended."), preset: 1 }]),
            slider("placeboSigmoidCenter", qsTr("Centre"), "", 0, 1, 0.01, 2, 0.75, isCustom("placeboSigmoidEnabled", "placeboSigmoidPreset")),
            slider("placeboSigmoidSlope", qsTr("Slope"), "", 1, 20, 0.1, 1, 6.5, isCustom("placeboSigmoidEnabled", "placeboSigmoidPreset"))
        ];
    }
    function deinterlacePage() {
        const on = () => !!Chiaki.settings.placeboDeinterlaceEnabled;
        return [
            customOnlyNote(),
            toggle("placeboDeinterlaceEnabled", qsTr("Deinterlacing"), ""),
            choice("placeboDeinterlacePreset", qsTr("Preset"), "", opts([qsTr("Default")]), on),
            choice("placeboDeinterlaceAlgorithm", qsTr("Algorithm"), "",
                   opts([[qsTr("Weave"), qsTr("Combine fields, no processing.")], [qsTr("Bob"), qsTr("Line doubling.")],
                         [qsTr("Yadif"), qsTr("Motion adaptive. Default.")], [qsTr("Bwdif"), qsTr("Motion adaptive, sharper.")]]), on),
            toggle("placeboDeinterlaceSkipSpatial", qsTr("Skip spatial check"), "", on)
        ];
    }
}
