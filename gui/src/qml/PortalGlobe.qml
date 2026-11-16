import QtQuick
import QtQuick.Window

// Full-bleed particle globe. Procedural (shaders/portalglobe.frag): no video loop,
// downloaded textures or console-vendor assets.
//   connecting -> faster spin, stronger corona and outward ripples
//   entering   -> a hole opens at the globe centre and grows over the whole item,
//                 revealing whatever is rendered underneath (the stream)
Item {
    id: globe
    property bool running: true
    property bool connecting: false
    property bool entering: false
    property bool drawBackdrop: true
    // Preview/recording hook: freezes the internal clocks so frames can be driven explicitly.
    property bool manual: false
    property real centerX: width * 0.5
    property real centerY: height * 0.53
    property real radius: Math.min(width, height) * 0.36
    // Accumulated animation clocks, exposed for tests.
    property real phase: 0
    property real spin: 0.6
    property real pulse: 0
    property real energy: connecting ? 1 : 0
    property real reveal: 0
    readonly property bool revealed: reveal >= 1
    // Only a real compile/load error switches to the fallback. (Hiding the effect while it is
    // still Uncompiled would stop it from ever compiling.)
    readonly property bool shaderReady: effect.status !== ShaderEffect.Error
    // chiaki-ng renders QML into an offscreen QQuickWindow that always reports Hidden, so
    // window visibility cannot be used here; pause on the application state instead.
    readonly property bool animate: running && visible && opacity > 0
        && Qt.application.state !== Qt.ApplicationSuspended && Qt.application.state !== Qt.ApplicationHidden
    signal revealFinished()

    Behavior on energy { enabled: !globe.manual; NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }
    Behavior on radius { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    Component.onCompleted: if (entering) enteringChanged()
    onEnteringChanged: {
        revealAnim.stop();
        if (manual)
            return;
        if (entering) {
            revealAnim.from = reveal;
            revealAnim.to = 1;
            revealAnim.duration = 1150;
        } else {
            revealAnim.from = reveal;
            revealAnim.to = 0;
            revealAnim.duration = 1;
        }
        revealAnim.start();
    }
    NumberAnimation {
        id: revealAnim
        target: globe
        property: "reveal"
        easing.type: Easing.InQuart
        onFinished: if (globe.entering) globe.revealFinished()
    }

    // Idle motion follows the wall clock so two globes (home screen and connection screen
    // cross-fading) line up exactly; only the extra "connecting" motion is accumulated.
    property real extraSpin: 0
    property real extraPulse: 0
    readonly property real spinPeriod: 2 * Math.PI * 10 / 0.07
    readonly property real pulsePeriod: 2 * Math.PI * 100 / 1.9
    // Paced timer instead of FrameAnimation: every frame costs an offscreen QML render plus
    // the libplacebo composite, so the slow idle motion runs at 30 fps (60 while connecting)
    // rather than at the panel's 90 Hz. The reveal animation itself is not throttled.
    property real lastTick: 0
    Timer {
        interval: globe.connecting ? 16 : 33
        repeat: true
        running: globe.animate && !globe.manual
        onRunningChanged: globe.lastTick = 0
        onTriggered: {
            const nowMs = Date.now();
            const dt = globe.lastTick > 0 ? Math.min((nowMs - globe.lastTick) / 1000, 0.1) : interval / 1000;
            globe.lastTick = nowMs;
            const now = nowMs / 1000;
            globe.phase += dt;
            globe.extraSpin = (globe.extraSpin + dt * 0.22 * globe.energy) % (2 * Math.PI);
            globe.extraPulse = (globe.extraPulse + dt * 2.9 * globe.energy) % (2 * Math.PI);
            globe.spin = (now % globe.spinPeriod) * 0.07 + globe.extraSpin;
            globe.pulse = (now % globe.pulsePeriod) * 1.9 + globe.extraPulse;
        }
    }

    ShaderEffect {
        id: effect
        anchors.fill: parent
        visible: globe.shaderReady
        blending: true
        fragmentShader: "qrc:/portal/portalglobe.frag.qsb"
        property size size: Qt.size(width, height)
        property point center: Qt.point(globe.centerX, globe.centerY)
        property real radius: globe.radius
        property real time: globe.phase
        property real spin: globe.spin
        property real pulse: globe.pulse
        property real energy: globe.energy
        property real reveal: globe.reveal
        property real backdrop: globe.drawBackdrop ? 1 : 0
    }

    // Fallback when the shader is unavailable (no ShaderTools at build time, software renderer).
    Item {
        anchors.fill: parent
        visible: !globe.shaderReady
        opacity: 1 - globe.reveal
        Rectangle {
            anchors.fill: parent
            visible: globe.drawBackdrop
            gradient: Gradient {
                GradientStop { position: 0; color: "#050509" }
                GradientStop { position: 1; color: "#14141c" }
            }
        }
        Rectangle {
            x: globe.centerX - width / 2; y: globe.centerY - height / 2
            width: globe.radius * 2.5; height: width; radius: width / 2
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: "#00000000" }
                GradientStop { position: 0.5; color: "#0a3a8a" }
                GradientStop { position: 1; color: "#00000000" }
            }
            opacity: 0.35
        }
        Rectangle {
            x: globe.centerX - globe.radius; y: globe.centerY - globe.radius
            width: globe.radius * 2; height: width; radius: globe.radius
            color: "#04133a"
            border.width: 2; border.color: "#2f8fff"
        }
    }
}
