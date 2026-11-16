// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#ifndef CHIAKI_PSNPHONELOGIN_H
#define CHIAKI_PSNPHONELOGIN_H

#include <QObject>
#include <QHostAddress>
#include <QTimer>
#include <QUrl>

class QTcpServer;
class QTcpSocket;

// "Sign in with your phone": a tiny one-shot web page served on the local network.
// The Deck shows a QR code of pageUrl(); the phone opens it, signs in to PlayStation
// Network in a new tab and pastes back the address it lands on. The redirect URL (which
// carries the one-time authorization code) is handed to the normal token exchange.
//
// Safety: listens only on the Wi-Fi/LAN address, only while the dialog is open, for at most
// ten minutes; the page path contains a random 128-bit token; the first valid submission
// ends the session. No account data is ever sent anywhere but Sony.
class PsnPhoneLogin : public QObject
{
    Q_OBJECT
public:
    explicit PsnPhoneLogin(QObject *parent = nullptr);
    ~PsnPhoneLogin() override;

    // Starts the server; returns the page URL for the QR code, or an empty string.
    QString start(const QUrl &authorizeUrl, const QString &redirectPrefix);
    void stop();
    bool running() const;
    QString errorString() const { return error; }

signals:
    void redirectReceived(const QString &url, const QString &peer);
    void phoneConnected(const QString &peer);
    void expired();

private:
    void handleSocket(QTcpSocket *socket);
    void respond(QTcpSocket *socket, int status, const QByteArray &body);
    QByteArray page(bool done, const QString &message) const;
    static QHostAddress lanAddress();

    QTcpServer *server = nullptr;
    QTimer ttl;
    QString token;
    QUrl authorize_url;
    QString redirect_prefix;
    QString error;
    bool done = false;
};

#endif // CHIAKI_PSNPHONELOGIN_H
