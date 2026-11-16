import QtQuick
import org.streetpea.chiaking

// Settings (the main app settings) as Portal-style pages for PortalSettings.qml.
// Each row writes the same Chiaki.settings property, with the same values and the same
// side effects (restart prompts, bitrate resets), as the previous SettingsDialog controls.
QtObject {
    id: m
    // The SettingsDialog: provides openKeyMapping(), openControllerMapping(reset), openAbout().
    property var dialog: null
    // Which console the Streaming page edits (0 = PS4, 1 = PS5), as before.
    property int streamConsole: 1
    readonly property PortalSettingsModel stream: PortalSettingsModel {}

    // ---- helpers (same shapes as PortalSettingsModel) ---------------------------------------
    function has(prop) { return typeof Chiaki.settings[prop] !== "undefined"; }
    function slider(prop, label, detail, from, to, step, decimals, def, visible, extra) {
        const d = { type: "slider", label: label, detail: detail, from: from, to: to, step: step,
                    decimals: decimals, def: def, visible: visible,
                    get: () => Chiaki.settings[prop], set: v => Chiaki.settings[prop] = v };
        return Object.assign(d, extra || {});
    }
    function toggle(prop, label, detail, visible) {
        return { type: "toggle", label: label, detail: detail, visible: visible,
                 get: () => !!Chiaki.settings[prop], set: v => Chiaki.settings[prop] = v };
    }
    function choice(prop, label, detail, options, visible, note) {
        return { type: "choice", label: label, detail: detail, options: m.stream.opts(options), visible: visible, note: note,
                 get: () => Chiaki.settings[prop], set: i => Chiaki.settings[prop] = i };
    }
    function header(label, visible) { return { type: "header", label: label, visible: visible }; }
    function note(label, visible) { return { type: "note", label: label, visible: visible }; }
    function action(label, detail, run, visible, icon) {
        return { type: "action", label: label, detail: detail, run: run, visible: visible, icon: icon };
    }
    function page(label, detail, items, icon, value, visible) {
        return { type: "page", label: label, detail: detail, items: items, icon: icon, value: value, visible: visible };
    }
    function restart() {
        if (Chiaki.settings.restartApplication())
            Qt.quit();
    }
    readonly property var buttons: [qsTr("Not used"), qsTr("Cross"), qsTr("Circle"), qsTr("Square"), qsTr("Triangle"),
        qsTr("D-pad left"), qsTr("D-pad right"), qsTr("D-pad up"), qsTr("D-pad down"), qsTr("L1"), qsTr("R1"),
        qsTr("L3"), qsTr("R3"), qsTr("Options"), qsTr("Create / Share"), qsTr("Touchpad"), qsTr("PS")]
    function comboValue(prefix) {
        const parts = [1, 2, 3, 4].map(i => Chiaki.settings[prefix + i]).filter(v => v > 0).map(v => m.buttons[v]);
        return parts.length ? parts.join(" + ") : qsTr("Off");
    }
    function comboPage(prefix, label, detail) {
        return [1, 2, 3, 4].map(i => choice(prefix + i, qsTr("Button %1").arg(i), "", m.buttons))
            .concat([note(detail)]);
    }

    // ---- root -----------------------------------------------------------------------------
    function categories() {
        return [
            page(qsTr("General"), qsTr("How Remote Play starts and ends, Steam Deck options."), () => m.general(), "settings"),
            page(qsTr("Video"), qsTr("Picture quality, window and rendering."), () => m.video(), "picture"),
            page(qsTr("Streaming"), qsTr("Resolution, frame rate and bitrate for your console."), () => m.streaming(), "quality"),
            page(qsTr("Audio & Wi-Fi"), qsTr("Sound, microphone and weak-connection behaviour."), () => m.audio(), "volume"),
            page(qsTr("Consoles"), qsTr("Register, auto-connect and remove consoles."), () => m.consoles(), "console"),
            page(qsTr("Keyboard"), qsTr("Use the keyboard and mouse as a controller."), () => m.keyboard(), "options-badge"),
            page(qsTr("Controllers"), qsTr("Button layout, D-pad touch and vibration."), () => m.controllers(), "controller"),
            page(qsTr("Remote access"), qsTr("PlayStation Network sign-in to play away from home."), () => m.remote(), "globe",
                 () => Chiaki.settings.psnAuthToken ? (Chiaki.settings.psnOnlineId || qsTr("Signed in")) : qsTr("Signed out")),
            page(qsTr("Profiles & data"), qsTr("Profiles, backups, logs and about."), () => m.data(), "stats")
        ];
    }

    // ---- General ----------------------------------------------------------------------------
    function general() {
        return [
            header(qsTr("When you stop playing")),
            choice("disconnectAction", qsTr("When you disconnect"), qsTr("What happens to the console."),
                   [qsTr("Leave the console on"), qsTr("Put the console in rest mode"), [qsTr("Ask every time"), qsTr("Default.")]]),
            choice("suspendAction", qsTr("When this device sleeps"), "",
                   [[qsTr("Leave the console on"), qsTr("Default.")], qsTr("Put the console in rest mode")]),
            header(qsTr("Steam Deck"), () => m.has("steamDeckHaptics") || m.has("verticalDeck")),
            toggle("steamDeckHaptics", qsTr("True haptics"), qsTr("Better quality vibration, but noisier."), () => m.has("steamDeckHaptics")),
            toggle("verticalDeck", qsTr("Vertical orientation"), qsTr("Hold the Deck upright for motion controls."), () => m.has("verticalDeck")),
            header(qsTr("Stream menu")),
            toggle("streamMenuEnabled", qsTr("Stream menu button combo"), qsTr("Open the quick menu during a stream with a controller combo.")),
            page(qsTr("Button combo"), qsTr("Buttons held together to open the menu."), () => m.comboPage("streamMenuShortcut", "", qsTr("Default: L1 + R1 + L3 + R3.")),
                 "", () => m.comboValue("streamMenuShortcut"), () => !!Chiaki.settings.streamMenuEnabled),
            header(qsTr("Privacy")),
            toggle("streamerMode", qsTr("Streamer mode"), qsTr("Hides addresses and console IDs on screen.")),
            header(qsTr("Advanced")),
            choice("audioVideoDisabled", qsTr("Audio and video"), qsTr("Turn off parts of the stream, e.g. for input-only use."),
                   [[qsTr("Audio and video on"), qsTr("Default.")], qsTr("Audio off"), qsTr("Video off"), qsTr("Audio and video off")])
        ];
    }

    // ---- Video ------------------------------------------------------------------------------
    function video() {
        return [
            m.stream.renderingQuality(),
            action(qsTr("Picture settings"), qsTr("Custom scaling, debanding and colour (Rendering quality: Custom)."),
                   () => root.showPlaceboSettingsDialog(), () => Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom, "picture"),
            action(qsTr("Color & HDR"), qsTr("Display brightness, contrast and tone mapping."), () => root.showDisplaySettingsDialog(), undefined, "hdr"),
            header(qsTr("Window")),
            choice("windowType", qsTr("Window size"), qsTr("How the stream window is sized on the desktop."),
                   [qsTr("Stream resolution"), qsTr("Custom resolution"), qsTr("Adjust manually"), [qsTr("Fullscreen"), qsTr("Default.")],
                    [qsTr("Zoom"), qsTr("Adjust the zoom from the stream menu.")], qsTr("Stretch")]),
            { type: "text", label: qsTr("Custom width"), detail: qsTr("Pixels, 0–9999. Default 1920."), inputHint: Qt.ImhDigitsOnly,
              visible: () => Chiaki.settings.windowType == 1,
              get: () => Chiaki.settings.customResolutionWidth,
              set: t => { const n = parseInt(t); Chiaki.settings.customResolutionWidth = (n >= 0 && n <= 9999) ? n : 0; } },
            { type: "text", label: qsTr("Custom height"), detail: qsTr("Pixels, 0–9999. Default 1080."), inputHint: Qt.ImhDigitsOnly,
              visible: () => Chiaki.settings.windowType == 1,
              get: () => Chiaki.settings.customResolutionHeight,
              set: t => { const n = parseInt(t); Chiaki.settings.customResolutionHeight = (n >= 0 && n <= 9999) ? n : 0; } },
            toggle("fullscreenDoubleClick", qsTr("Double-click for fullscreen"), ""),
            toggle("hideCursor", qsTr("Hide the pointer while streaming"), qsTr("On by default.")),
            header(qsTr("Advanced")),
            page(qsTr("Decoding & rendering"), qsTr("Decoder, frame delivery, renderer. Some changes restart the app."), () => m.videoAdvanced(), "settings")
        ];
    }
    function videoAdvanced() {
        return [
            { type: "choice", label: qsTr("Hardware decoder"), detail: qsTr("Automatic picks the best decoder for this device."),
              options: (Chiaki.settings.availableDecoders || []).map((n, i) => ({ label: i === 0 ? qsTr("Automatic") : n, detail: "" })),
              get: () => Math.max(0, (Chiaki.settings.availableDecoders || []).indexOf(Chiaki.settings.decoder)),
              set: i => Chiaki.settings.decoder = i ? Chiaki.settings.availableDecoders[i] : "" },
            toggle("useZeroCopy", qsTr("Zero-copy decoding"), qsTr("Pass decoded frames to the GPU without copying.")),
            { type: "toggle", label: qsTr("Vertical sync"), detail: qsTr("Off by default. With OpenGL the app restarts."),
              get: () => !!Chiaki.settings.vSyncEnabled,
              set: v => { Chiaki.settings.vSyncEnabled = v; if (Chiaki.window.runtimeRendererBackend === 1 && Chiaki.settings.restartApplication()) Qt.quit(); } },
            { type: "choice", label: qsTr("Frame delivery"), detail: qsTr("Changing this restarts the app."),
              options: m.stream.opts([[qsTr("Direct mapping"), qsTr("Lowest latency. Default.")], [qsTr("Frame queue"), qsTr("Allows a frame mixer.")]]),
              get: () => Chiaki.settings.directFrameMapping ? 0 : 1,
              set: i => { const direct = i === 0; if (direct === Chiaki.settings.directFrameMapping) return; Chiaki.settings.directFrameMapping = direct; m.restart(); } },
            choice("placeboFrameMixer", qsTr("Frame mixer"), qsTr("Smooths uneven frame pacing. Only with Frame queue."),
                   [[qsTr("None"), qsTr("Default.")], qsTr("Oversample"), qsTr("Hermite"), qsTr("Linear"), qsTr("Cubic")],
                   () => !Chiaki.settings.directFrameMapping),
            { type: "choice", label: qsTr("Renderer"), detail: qsTr("Changing this restarts the app."),
              options: m.stream.opts([[qsTr("Vulkan"), qsTr("Default. Needed for HDR.")], qsTr("OpenGL")]),
              get: () => Chiaki.settings.rendererBackend,
              set: i => { if (i === Chiaki.settings.rendererBackend) return; Chiaki.settings.rendererBackend = i; m.restart(); } },
            toggle("vulkanDeferredSwap", qsTr("Vulkan deferred swap"), "", () => Chiaki.settings.rendererBackend == 0)
        ];
    }

    // ---- Streaming --------------------------------------------------------------------------
    // Setting names per console and place: resolutionLocalPS5, fpsRemotePS4, bitrateLocalPS5, codecRemotePS5...
    function autoBitrate(res) { return ({ 1: 2, 2: 6, 3: 10, 4: 15 })[res] || 0; }
    function streamRows(place, placeLabel) {
        const remote = place === "Remote";
        const ps = () => m.streamConsole === 1 ? "PS5" : "PS4";
        const key = name => name + place + ps();
        return [
            header(placeLabel),
            { type: "choice", label: qsTr("Resolution"), detail: qsTr("Changing it resets the bitrate to automatic."),
              get options() {
                  return m.stream.opts(m.streamConsole === 1
                      ? [qsTr("360p"), qsTr("540p"), remote ? [qsTr("720p"), qsTr("Default.")] : qsTr("720p"), remote ? qsTr("1080p") : [qsTr("1080p"), qsTr("Default.")]]
                      : [qsTr("360p"), qsTr("540p"), [qsTr("720p"), qsTr("Default.")], [qsTr("1080p"), qsTr("PS4 Pro only.")]]);
              },
              get: () => Chiaki.settings[key("resolution")] - 1,
              set: i => { Chiaki.settings[key("resolution")] = i + 1; Chiaki.settings[key("bitrate")] = 0; } },
            { type: "choice", label: qsTr("Frame rate"), detail: "",
              options: m.stream.opts([qsTr("30 fps"), [qsTr("60 fps"), qsTr("Default.")]]),
              get: () => (Chiaki.settings[key("fps")] / 30) - 1,
              set: i => Chiaki.settings[key("fps")] = (i + 1) * 30 },
            { type: "slider", label: qsTr("Bitrate"), detail: qsTr("Higher is sharper but needs a stronger connection."),
              from: 2, to: 100, step: 1, decimals: 0,
              get: () => Chiaki.settings[key("bitrate")] / 1000 ? Chiaki.settings[key("bitrate")] / 1000 : m.autoBitrate(Chiaki.settings[key("resolution")]),
              set: v => Chiaki.settings[key("bitrate")] = v * 1000,
              fmt: v => Chiaki.settings[key("bitrate")] ? qsTr("%1 Mbps").arg(v) : qsTr("Automatic (%1 Mbps)").arg(v),
              defText: qsTr("✕ returns to automatic."),
              reset: () => Chiaki.settings[key("bitrate")] = 0 },
            { type: "choice", label: qsTr("Video codec"), detail: qsTr("HDR needs H.265 HDR and the Vulkan renderer."),
              visible: () => m.streamConsole === 1,
              get options() {
                  return m.stream.opts(Chiaki.settings.rendererBackend === 1
                      ? [qsTr("H.264"), [qsTr("H.265"), qsTr("Default.")]]
                      : [qsTr("H.264"), [qsTr("H.265"), qsTr("Default.")], [qsTr("H.265 HDR"), qsTr("HDR picture when the PS5 outputs HDR.")]]);
              },
              get: () => Chiaki.settings[key("codec")],
              set: i => Chiaki.settings[key("codec")] = i }
        ];
    }
    function streaming() {
        const rows = [
            { type: "choice", icon: "console", label: qsTr("Console"), detail: qsTr("Settings below are for this console type."),
              options: m.stream.opts([qsTr("PS4"), qsTr("PS5")]),
              get: () => m.streamConsole, set: i => m.streamConsole = i }
        ].concat(streamRows("Local", qsTr("At home (same network)")), streamRows("Remote", qsTr("Away from home (via PSN)")));
        return rows;
    }

    // ---- Audio & Wi-Fi ----------------------------------------------------------------------
    function audio() {
        return [
            header(qsTr("Sound")),
            slider("audioVolume", qsTr("Volume"), "", 0, 128, 1, 0, 128, undefined, { fmt: v => Math.round(v / 128 * 100) + "%" }),
            { type: "choice", label: qsTr("Output device"), detail: "",
              options: [{ label: qsTr("Automatic"), detail: qsTr("Default.") }].concat((Chiaki.settings.availableAudioOutDevices || []).map(n => ({ label: n, detail: "" }))),
              get: () => Math.max(0, [""].concat(Chiaki.settings.availableAudioOutDevices || []).indexOf(Chiaki.settings.audioOutDevice)),
              set: i => Chiaki.settings.audioOutDevice = i ? Chiaki.settings.availableAudioOutDevices[i - 1] : "" },
            header(qsTr("Microphone")),
            toggle("startMicUnmuted", qsTr("Start with the microphone on"), ""),
            { type: "choice", label: qsTr("Input device"), detail: "",
              options: [{ label: qsTr("Automatic"), detail: qsTr("Default.") }].concat((Chiaki.settings.availableAudioInDevices || []).map(n => ({ label: n, detail: "" }))),
              get: () => Math.max(0, [""].concat(Chiaki.settings.availableAudioInDevices || []).indexOf(Chiaki.settings.audioInDevice)),
              set: i => Chiaki.settings.audioInDevice = i ? Chiaki.settings.availableAudioInDevices[i - 1] : "" },
            toggle("speechProcessing", qsTr("Noise suppression & echo cancellation"), "", () => m.has("speechProcessing")),
            slider("noiseSuppressLevel", qsTr("Noise to suppress"), "", 0, 60, 1, 0, 6, () => m.has("speechProcessing") && !!Chiaki.settings.speechProcessing, { unit: "dB" }),
            slider("echoSuppressLevel", qsTr("Echo to suppress"), "", 0, 60, 1, 0, 30, () => m.has("speechProcessing") && !!Chiaki.settings.speechProcessing, { unit: "dB" }),
            header(qsTr("Connection")),
            toggle("showStreamStats", qsTr("Performance overlay"), qsTr("Bitrate and packet loss during play.")),
            slider("wifiDroppedNotif", qsTr("Weak Wi-Fi warning"), qsTr("Warn when this share of packets is lost."), 0, 100, 1, 0, 3, undefined, { unit: "%" }),
            header(qsTr("Advanced")),
            { type: "slider", label: qsTr("Audio buffer"), detail: qsTr("Larger is smoother on weak Wi-Fi, but adds delay."),
              from: 1, to: 10, step: 1, decimals: 0, def: 5,
              get: () => Chiaki.settings.audioBufferSize / 1920 ? Chiaki.settings.audioBufferSize / 1920 : 5,
              set: v => Chiaki.settings.audioBufferSize = v * 1920, fmt: v => (v * 10).toFixed(0) + " ms" },
            slider("packetLossReportedMax", qsTr("Reported packet loss cap"), qsTr("Highest loss reported to the console's bitrate control."), 0, 100, 1, 0, 5, undefined, { unit: "%" }),
            toggle("iDROnFECFailureEnabled", qsTr("Request a key frame after errors"), qsTr("Recovers faster from broken frames."))
        ];
    }

    // ---- Consoles ---------------------------------------------------------------------------
    function hostLabel(h) { return Chiaki.settings.streamerMode ? (h.ps5 ? "PS5" : "PS4") : (h.name || h.mac); }
    function consoles() {
        const hosts = Chiaki.settings.registeredHosts || [];
        const hidden = Chiaki.hiddenHosts || [];
        let rows = [
            action(qsTr("Register a console"), qsTr("Pair a PS5 or PS4 with this device."), () => root.showRegistDialog("255.255.255.255", true), undefined, "plus"),
            header(qsTr("Registered consoles"))
        ];
        if (!hosts.length)
            rows.push(note(qsTr("No consoles registered yet.")));
        hosts.forEach((h, index) => {
            rows.push(page(m.hostLabel(h), (h.ps5 ? "PS5" : "PS4") + (Chiaki.settings.streamerMode ? "" : " · " + h.mac),
                () => [
                    { type: "toggle", label: qsTr("Auto-connect"), detail: qsTr("Connect to this console when the app starts."),
                      get: () => Chiaki.settings.autoConnectMac == h.mac,
                      set: v => Chiaki.settings.autoConnectMac = v ? h.mac : "" },
                    action(qsTr("Delete this console"), qsTr("You will need to register it again."),
                           view => root.showConfirmDialog(qsTr("Delete Console"), qsTr("Are you sure you want to delete this console?"),
                                                          () => { Chiaki.settings.deleteRegisteredHost(index); view.back(); }))
                ], "console", () => Chiaki.settings.autoConnectMac == h.mac ? qsTr("Auto-connect") : ""));
        });
        if (hidden.length) {
            rows.push(header(qsTr("Hidden consoles")));
            hidden.forEach(h => rows.push(action(Chiaki.settings.streamerMode ? qsTr("Hidden console") : h.name,
                Chiaki.settings.streamerMode ? qsTr("Select to unhide") : h.mac + " · " + qsTr("select to unhide"),
                () => root.showConfirmDialog(qsTr("Unhide Console"), qsTr("Are you sure you want to unhide this console?"), () => Chiaki.unhideHost(h.mac)))));
        }
        return rows;
    }

    // ---- Keyboard ---------------------------------------------------------------------------
    function keyboard() {
        return [
            toggle("keyboardEnabled", qsTr("Keyboard as controller"), qsTr("Play with a keyboard using the key mapping below.")),
            toggle("mouseTouchEnabled", qsTr("Mouse as touchpad"), qsTr("Mouse movement and clicks act as the DualSense touchpad.")),
            action(qsTr("Edit key mapping"), qsTr("Choose which key presses each controller button."), () => m.dialog.openKeyMapping(), undefined, "options-badge"),
            action(qsTr("Reset all keys"), qsTr("Restore the default key mapping."),
                   () => root.showConfirmDialog(qsTr("Reset all keys"), qsTr("Restore the default key mapping?"), () => Chiaki.settings.clearKeyMapping()))
        ];
    }

    // ---- Controllers ------------------------------------------------------------------------
    function controllers() {
        return [
            header(qsTr("Vibration")),
            choice("rumbleHapticsIntensity", qsTr("Rumble strength"), qsTr("For controllers without DualSense haptics."),
                   [qsTr("Off"), qsTr("Very weak"), qsTr("Weak"), [qsTr("Normal"), qsTr("Default.")], qsTr("Strong"), qsTr("Very strong")]),
            slider("hapticOverride", qsTr("Haptics intensity"), qsTr("Relative to the console's own setting."), 0, 2, 0.1, 1, 1, undefined,
                   { fmt: v => (v > 0.99 && v < 1.01) ? qsTr("Console setting") : qsTr("%1% of console").arg((v * 100).toFixed(0)) }),
            header(qsTr("Buttons")),
            toggle("buttonsByPosition", qsTr("Buttons by position"), qsTr("Map face buttons by position instead of by label (Nintendo layouts).")),
            action(qsTr("Change controller mapping"), qsTr("Remap buttons on the connected controller."), () => m.dialog.openControllerMapping(false), undefined, "controller"),
            action(qsTr("Reset controller mapping"), "", () => m.dialog.openControllerMapping(true)),
            header(qsTr("D-pad as touchpad")),
            toggle("dpadTouchEnabled", qsTr("D-pad touchpad emulation"), qsTr("Switch the D-pad to touchpad swipes with a button combo.")),
            slider("dpadTouchIncrement", qsTr("Swipe step"), "", 1, 1079, 1, 0, 30, () => !!Chiaki.settings.dpadTouchEnabled,
                   { fmt: v => qsTr("%1 mm").arg((v / 100).toFixed(2)) }),
            page(qsTr("Switch combo"), qsTr("Buttons held together to switch D-pad mode."),
                 () => m.comboPage("dpadTouchShortcut", "", qsTr("Default: L1 + R1 + D-pad up.")), "",
                 () => m.comboValue("dpadTouchShortcut"), () => !!Chiaki.settings.dpadTouchEnabled),
            header(qsTr("Advanced")),
            toggle("allowJoystickBackgroundEvents", qsTr("Controller input in background"), qsTr("Keep reading the controller when the app is not focused."))
        ];
    }

    // ---- Remote access ----------------------------------------------------------------------
    function signedIn() {
        return !!(Chiaki.settings.psnRefreshToken && Chiaki.settings.psnAuthToken && Chiaki.settings.psnAuthTokenExpiry && Chiaki.settings.psnAccountId);
    }
    function remote() {
        return [
            { type: "note", card: true, icon: "globe", tone: "good", visible: () => m.signedIn(),
              label: () => Chiaki.settings.psnOnlineId ? qsTr("Signed in as %1").arg(Chiaki.settings.psnOnlineId) : qsTr("Signed in to PlayStation Network") },
            { type: "note", card: true, icon: "globe", visible: () => !m.signedIn(),
              label: qsTr("Not signed in. Sign in to register consoles automatically and play away from home.") },
            action(qsTr("Sign in to PlayStation Network"), qsTr("Scan a QR code with your phone."), () => root.showPSNTokenDialog(false),
                   () => !m.signedIn(), "globe"),
            action(qsTr("Sign out"), qsTr("Removes the PSN sign-in from this device."),
                   () => root.showConfirmDialog(qsTr("Sign out"), qsTr("Sign out of PlayStation Network on this device?"), () => {
                        Chiaki.settings.psnRefreshToken = "";
                        Chiaki.settings.psnAuthToken = "";
                        Chiaki.settings.psnAuthTokenExpiry = "";
                        Chiaki.settings.psnAccountId = "";
                        Chiaki.settings.psnOnlineId = "";
                   }), () => m.signedIn()),
            header(qsTr("Advanced")),
            toggle("portGuessingEnabled", qsTr("Force STUN port guessing"), qsTr("Can help on strict networks (CGNAT, mobile hotspots).")),
            slider("portGuessCount", qsTr("Port guesses"), "", 0, 75, 1, 0, 75),
            slider("portGuessSocketCount", qsTr("Port guess sockets"), "", 0, 500, 1, 0, 250)
        ];
    }

    // ---- Profiles & data --------------------------------------------------------------------
    function data() {
        return [
            action(qsTr("Profiles"), qsTr("Switch between saved setting profiles."), () => root.showProfileDialog(), undefined, "stats"),
            action(qsTr("Export settings"), qsTr("Save all settings to a file."), () => Chiaki.settings.exportSettings()),
            action(qsTr("Import settings"), qsTr("Load settings from a file."), () => Chiaki.settings.importSettings()),
            header(qsTr("Logs")),
            toggle("logSanitize", qsTr("Sanitize logs"), qsTr("Remove personal data from logs. On by default.")),
            toggle("logVerbose", qsTr("Verbose logging"), qsTr("More detail for troubleshooting.")),
            action(qsTr("Open log folder"), () => Chiaki.settings.streamerMode ? "" : Chiaki.settings.logDirectory,
                   () => Qt.openUrlExternally("file://" + Chiaki.settings.logDirectory)),
            header(qsTr("About")),
            action(qsTr("About %1-ng").arg(Qt.application.name), "", () => m.dialog.openAbout())
        ];
    }
}
