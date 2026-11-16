// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
#include "psnphonelogin.h"

#include <QNetworkInterface>
#include <QRandomGenerator>
#include <QTcpServer>
#include <QTcpSocket>
#include <QUrlQuery>

static constexpr int kTtlMs = 10 * 60 * 1000;
static constexpr int kMaxRequest = 32 * 1024;

PsnPhoneLogin::PsnPhoneLogin(QObject *parent)
    : QObject(parent)
{
    ttl.setSingleShot(true);
    connect(&ttl, &QTimer::timeout, this, [this]() {
        stop();
        emit expired();
    });
}

PsnPhoneLogin::~PsnPhoneLogin()
{
    stop();
}

bool PsnPhoneLogin::running() const
{
    return server && server->isListening();
}

QHostAddress PsnPhoneLogin::lanAddress()
{
    QHostAddress fallback;
    for (const QNetworkInterface &iface : QNetworkInterface::allInterfaces()) {
        const auto flags = iface.flags();
        if (!(flags & QNetworkInterface::IsUp) || !(flags & QNetworkInterface::IsRunning)
            || (flags & QNetworkInterface::IsLoopBack))
            continue;
        for (const QNetworkAddressEntry &entry : iface.addressEntries()) {
            const QHostAddress ip = entry.ip();
            if (ip.protocol() != QAbstractSocket::IPv4Protocol)
                continue;
            const quint32 v = ip.toIPv4Address();
            const bool priv = (v >> 24) == 10 || (v >> 20) == ((172u << 4) | 1u) || (v >> 16) == ((192u << 8) | 168u);
            if (!priv)
                continue;
            // Prefer Wi-Fi: the phone is on the same wireless network.
            if (iface.name().startsWith(QLatin1String("wl")))
                return ip;
            if (fallback.isNull())
                fallback = ip;
        }
    }
    return fallback;
}

QString PsnPhoneLogin::start(const QUrl &authorizeUrl, const QString &redirectPrefix)
{
    stop();
    error.clear();
    done = false;
    authorize_url = authorizeUrl;
    redirect_prefix = redirectPrefix;

    const QHostAddress ip = lanAddress();
    if (ip.isNull()) {
        error = tr("This device is not connected to a local network.");
        return QString();
    }
    quint32 raw[4];
    QRandomGenerator::system()->fillRange(raw);
    token = QByteArray(reinterpret_cast<const char *>(raw), sizeof(raw)).toHex();

    server = new QTcpServer(this);
    // A fixed port range keeps the address short and stable; fall back to any free port.
    bool listening = false;
    for (quint16 port = 47990; port < 48000 && !listening; ++port)
        listening = server->listen(ip, port);
    if (!listening)
        listening = server->listen(ip, 0);
    if (!listening) {
        error = server->errorString();
        server->deleteLater();
        server = nullptr;
        return QString();
    }
    connect(server, &QTcpServer::newConnection, this, [this]() {
        while (server && server->hasPendingConnections()) {
            QTcpSocket *socket = server->nextPendingConnection();
            connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
            connect(socket, &QTcpSocket::readyRead, this, [this, socket]() { handleSocket(socket); });
        }
    });
    ttl.start(kTtlMs);
    return QStringLiteral("http://%1:%2/%3").arg(ip.toString()).arg(server->serverPort()).arg(token);
}

void PsnPhoneLogin::stop()
{
    ttl.stop();
    if (server) {
        server->close();
        server->deleteLater();
        server = nullptr;
    }
}

void PsnPhoneLogin::respond(QTcpSocket *socket, int status, const QByteArray &body)
{
    const QByteArray reason = status == 200 ? "OK" : status == 400 ? "Bad Request" : status == 410 ? "Gone" : "Not Found";
    QByteArray head = "HTTP/1.1 " + QByteArray::number(status) + " " + reason + "\r\n"
        "Content-Type: text/html; charset=utf-8\r\n"
        "Cache-Control: no-store\r\n"
        "Referrer-Policy: no-referrer\r\n"
        "X-Content-Type-Options: nosniff\r\n"
        "Connection: close\r\n"
        "Content-Length: " + QByteArray::number(body.size()) + "\r\n\r\n";
    socket->write(head + body);
    socket->disconnectFromHost();
}

void PsnPhoneLogin::handleSocket(QTcpSocket *socket)
{
    QByteArray buffer = socket->property("buf").toByteArray() + socket->readAll();
    if (buffer.size() > kMaxRequest) {
        socket->abort();
        return;
    }
    const int headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd < 0) {
        socket->setProperty("buf", buffer);
        return;
    }
    const QList<QByteArray> lines = buffer.left(headerEnd).split('\n');
    const QList<QByteArray> request = lines.value(0).trimmed().split(' ');
    const QByteArray method = request.value(0);
    const QByteArray path = request.value(1);
    int contentLength = 0;
    for (const QByteArray &line : lines) {
        if (line.toLower().startsWith("content-length:"))
            contentLength = line.mid(15).trimmed().toInt();
    }
    const QByteArray body = buffer.mid(headerEnd + 4);
    if (body.size() < contentLength) {
        socket->setProperty("buf", buffer);
        return;
    }

    const QByteArray base = "/" + token.toLatin1();
    if (path != base && path != base + "/submit") {
        respond(socket, 404, "Not found");
        return;
    }
    if (done) {
        respond(socket, 410, page(true, tr("Already signed in. You can close this page.")));
        return;
    }
    if (method == "GET" && path == base) {
        emit phoneConnected(socket->peerAddress().toString());
        respond(socket, 200, page(false, QString()));
        return;
    }
    if (method == "POST" && path == base + "/submit") {
        const QString value = QUrlQuery(QString::fromUtf8(body.left(contentLength)).replace('+', ' '))
            .queryItemValue(QStringLiteral("url"), QUrl::FullyDecoded).trimmed();
        const QUrl url(value);
        const bool valid = value.startsWith(redirect_prefix) && !QUrlQuery(url).queryItemValue(QStringLiteral("code")).isEmpty();
        if (!valid) {
            respond(socket, 400, page(false, tr("That is not the sign-in address yet. After signing in, copy the address of the page "
                                                "you end on (it starts with %1) and paste it here.").arg(redirect_prefix)));
            return;
        }
        done = true;
        respond(socket, 200, page(true, tr("Done! Finish on your Steam Deck. You can close this page.")));
        emit redirectReceived(value, socket->peerAddress().toString());
        QTimer::singleShot(2000, this, &PsnPhoneLogin::stop);
        return;
    }
    respond(socket, 404, "Not found");
}

QByteArray PsnPhoneLogin::page(bool finished, const QString &message) const
{
    const QString login = authorize_url.toString(QUrl::FullyEncoded).toHtmlEscaped();
    const QString msg = message.toHtmlEscaped();
    QString html = QStringLiteral(R"HTML(<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sign in for your Steam Deck</title>
<style>
:root{color-scheme:dark}
body{margin:0;font:17px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#0c0e13;color:#f4f2fa}
main{max-width:520px;margin:0 auto;padding:28px 20px 40px}
h1{font-size:26px;font-weight:500;margin:0 0 6px}
p{color:#c9c5d8;margin:8px 0}
.step{background:#1a1e27;border-radius:18px;padding:18px;margin:16px 0}
.n{display:inline-block;width:28px;height:28px;border-radius:14px;background:#24344c;text-align:center;line-height:28px;margin-right:8px;font-weight:600}
a.btn,button{display:block;width:100%;box-sizing:border-box;margin-top:12px;padding:16px;border:0;border-radius:28px;
 background:#fff;color:#101116;font:600 18px system-ui,sans-serif;text-align:center;text-decoration:none}
button.secondary{background:#232a36;color:#f4f2fa}
textarea{width:100%;box-sizing:border-box;min-height:96px;margin-top:12px;padding:12px;border-radius:14px;border:2px solid #2b3140;
 background:#0f1219;color:#f4f2fa;font:15px ui-monospace,monospace}
.msg{padding:14px;border-radius:14px;background:#24344c;margin:16px 0}
.ok{background:#173a2a}
small{color:#8f8ba0}
</style></head><body><main>
<h1>Sign in for your Steam Deck</h1>
)HTML");
    if (finished) {
        html += QStringLiteral("<div class=\"msg ok\">%1</div></main></body></html>").arg(msg);
        return html.toUtf8();
    }
    if (!msg.isEmpty())
        html += QStringLiteral("<div class=\"msg\">%1</div>").arg(msg);
    html += QStringLiteral(R"HTML(
<div class="step"><span class="n">1</span><b>Sign in to PlayStation</b>
<p>Opens Sony's sign-in page in a new tab.</p>
<a class="btn" href="%1" target="_blank" rel="noopener noreferrer">Sign in to PlayStation</a></div>
<div class="step"><span class="n">2</span><b>Copy the address you end on</b>
<p>After signing in you land on a mostly empty page. Tap the address bar and copy the whole address,
then come back to this tab.</p></div>
<form class="step" id="f" method="post" action="%2/submit"><span class="n">3</span><b>Paste it here</b>
<p>Long-press the box below and choose <b>Paste</b>. It is sent automatically.</p>
<textarea name="url" id="u" placeholder="https://remoteplay.dl.playstation.net/remoteplay/redirect?code=…" autocapitalize="off" autocorrect="off" spellcheck="false"></textarea>
<button type="button" class="secondary" id="p" hidden>Paste from clipboard</button>
<button type="submit">Send to Steam Deck</button>
<p><small>The address is sent only to your Steam Deck on this Wi-Fi. It contains a one-time code, not your password.</small></p>
</form>
<script>
const u=document.getElementById('u'),f=document.getElementById('f'),p=document.getElementById('p');
const send=()=>{ if(/[?&]code=/.test(u.value)) f.submit(); };
u.addEventListener('input',send); u.addEventListener('paste',()=>setTimeout(send,50));
if(window.isSecureContext&&navigator.clipboard&&navigator.clipboard.readText){ p.hidden=false;
 p.onclick=async()=>{ try{ u.value=await navigator.clipboard.readText(); send(); }catch(e){ u.focus(); } }; }
</script>
</main></body></html>)HTML").arg(login, QStringLiteral("/") + token);
    return html.toUtf8();
}
