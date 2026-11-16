import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.streetpea.chiaking

import "controls" as C

// "Sign in with your phone": QR code of a one-time page served by this device on the local
// network (PsnPhoneLogin). The phone signs in to PlayStation Network and pastes back the
// address it lands on; the token exchange is the same Chiaki.initPsnAuth() used by
// PSNTokenDialog, which stays available as "Sign in on this device instead".
DialogView {
    id: dialog
    property var psnurl
    property var expired
    property string pageUrl: ""
    // waiting | phone | signing | done | failed | expired | offline
    property string state_: "waiting"
    property string detail: ""
    property bool spatialNavScope: true
    title: expired ? qsTr("Sign in again to PlayStation Network") : qsTr("Sign in to PlayStation Network")
    chrome: false
    buttonVisible: false

    function startServer() {
        pageUrl = Chiaki.startPsnPhoneLogin();
        detail = "";
        state_ = pageUrl ? "waiting" : "offline";
        if (!pageUrl)
            detail = Chiaki.psnPhoneLoginError();
    }
    function useThisDevice() {
        Chiaki.stopPsnPhoneLogin();
        root.showPSNTokenDialogClassic(psnurl, expired);
    }
    StackView.onActivated: {
        Chiaki.settings.remotePlayAsk = true;
        if (!pageUrl) startServer();
        primaryButton.forceActiveFocus(Qt.TabFocusReason);
    }
    StackView.onDeactivating: Chiaki.stopPsnPhoneLogin()
    Component.onDestruction: Chiaki.stopPsnPhoneLogin()

    component Step: RowLayout {
        id: step
        property int n
        property string text
        property bool active: false
        spacing: 16
        Rectangle {
            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
            Layout.alignment: Qt.AlignTop
            color: step.active ? "#ffffff" : "#24344c"
            Text { anchors.centerIn: parent; text: step.n; font.pixelSize: 17; font.weight: Font.DemiBold
                   color: step.active ? "#101116" : "#ffffff" }
        }
        Label { Layout.fillWidth: true; text: step.text; wrapMode: Text.WordWrap; font.pixelSize: 18; color: "#f4f2fa" }
    }


    Item {
        Keys.onYesPressed: dialog.useThisDevice()
        Connections {
            target: Chiaki
            function onPsnPhoneLoginConnected(peer) {
                if (dialog.state_ === "waiting") dialog.state_ = "phone";
            }
            function onPsnPhoneLoginExpired() {
                if (dialog.state_ !== "done" && dialog.state_ !== "signing") dialog.state_ = "expired";
            }
            function onPsnPhoneLoginRedirect(url, peer) {
                dialog.state_ = "signing";
                dialog.detail = "";
                Chiaki.initPsnAuth(url, function(msg, ok, done) {
                    if (ok)
                        Chiaki.settings.remotePlayAsk = false;
                    if (!done)
                        return;
                    if (ok) {
                        dialog.state_ = "done";
                        closeTimer.start();
                    } else {
                        dialog.state_ = "failed";
                        dialog.detail = msg;
                    }
                });
            }
        }
        Timer { id: closeTimer; interval: 1800; onTriggered: dialog.close() }
        RowLayout {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.topMargin: 18; anchors.leftMargin: 32; anchors.rightMargin: 32
            spacing: 16
            RoundButton {
                Layout.preferredWidth: 48; Layout.preferredHeight: 48
                focusPolicy: Qt.NoFocus
                icon.source: "qrc:/icons/portal/back.svg"
                icon.width: 22; icon.height: 22; icon.color: "#ffffff"
                background: Rectangle { radius: 24; color: parent.hovered ? "#2d3544" : "#232a36" }
                onClicked: dialog.close()
                Accessible.name: qsTr("Back")
            }
            Label { Layout.fillWidth: true; text: dialog.title; font.pixelSize: 28; color: "#ffffff"; elide: Text.ElideRight }
        }

        RowLayout {
            anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: actions.top }
            anchors.margins: 32
            spacing: 40

            // QR card
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 340; Layout.preferredHeight: 340
                    radius: 24
                    color: "#ffffff"
                    opacity: dialog.state_ === "expired" || dialog.state_ === "offline" ? 0.25 : 1
                    Image {
                        anchors.centerIn: parent
                        width: 312; height: 312
                        visible: !!dialog.pageUrl
                        smooth: false
                        sourceSize: Qt.size(312, 312)
                        source: dialog.pageUrl ? "image://qr/" + encodeURIComponent(dialog.pageUrl) : ""
                        fillMode: Image.PreserveAspectFit
                    }
                }
                Label {
                    Layout.preferredWidth: 340
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Phone and Steam Deck must be on the same Wi-Fi.")
                    color: "#a9a5ba"; font.pixelSize: 14; wrapMode: Text.WordWrap
                }
            }

            // Steps and status
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 14
                Step { Layout.fillWidth: true; n: 1; active: dialog.state_ === "waiting"
                       text: qsTr("Scan the code with your phone's camera.") }
                Step { Layout.fillWidth: true; n: 2; active: dialog.state_ === "phone"
                       text: qsTr("Tap “Sign in to PlayStation” and sign in.") }
                Step { Layout.fillWidth: true; n: 3; active: dialog.state_ === "phone"
                       text: qsTr("Copy the address of the page you end on and paste it back on the first page.") }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    implicitHeight: statusColumn.implicitHeight + 32
                    radius: 18
                    color: dialog.state_ === "done" ? "#173a2a" : dialog.state_ === "failed" || dialog.state_ === "offline" ? "#3a1f22" : "#1a1e27"
                    ColumnLayout {
                        id: statusColumn
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        anchors.leftMargin: 20; anchors.rightMargin: 20
                        spacing: 4
                        RowLayout {
                            spacing: 12
                            BusyIndicator {
                                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                running: visible
                                visible: dialog.state_ === "waiting" || dialog.state_ === "phone" || dialog.state_ === "signing"
                                Material.accent: "#8fb8ff"
                            }
                            Label {
                                Layout.fillWidth: true
                                font.pixelSize: 18
                                color: "#ffffff"
                                wrapMode: Text.WordWrap
                                text: ({
                                    waiting: qsTr("Waiting for your phone…"),
                                    phone: qsTr("Phone connected. Finish signing in on your phone."),
                                    signing: qsTr("Signing in…"),
                                    done: qsTr("Signed in. Remote Play via PSN is ready."),
                                    failed: qsTr("Sign-in didn't finish."),
                                    expired: qsTr("This code has expired."),
                                    offline: qsTr("Can't start phone sign-in.")
                                })[dialog.state_]
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text
                            text: dialog.detail
                            color: "#c9c5d8"; font.pixelSize: 14; wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        RowLayout {
            id: actions
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
            spacing: 14
            C.DialogButton {
                id: primaryButton
                text: dialog.state_ === "expired" || dialog.state_ === "failed" || dialog.state_ === "offline"
                    ? qsTr("New code") : qsTr("Sign in on this Deck instead")
                glyph: "cross"
                onClicked: {
                    if (dialog.state_ === "expired" || dialog.state_ === "failed" || dialog.state_ === "offline")
                        dialog.startServer();
                    else
                        dialog.useThisDevice();
                }
            }
            C.DialogButton {
                text: qsTr("Back")
                glyph: "moon"
                onClicked: dialog.close()
            }
        }
    }
}
