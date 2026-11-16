#include "wifimonitor.h"

#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>

#include <algorithm>

namespace {
constexpr int kPollMs = 3000;
constexpr int kStepTimeoutMs = 2000;
constexpr int kRxHistory = 5;
constexpr int kScanCheckEvery = 10; // polls between nmcli checks (the lock rarely changes)
}

WifiMonitor::WifiMonitor(QObject *parent)
    : QObject(parent)
{
    timer.setInterval(kPollMs);
    connect(&timer, &QTimer::timeout, this, &WifiMonitor::poll);
}

void WifiMonitor::setActive(bool active)
{
    if (active == is_active)
        return;
    is_active = active;
    emit activeChanged();
#ifdef Q_OS_LINUX
    if (is_active) {
        poll();
        timer.start();
    } else {
        timer.stop();
    }
#endif
}

int WifiMonitor::channel() const
{
    const int f = frequency_mhz;
    if (f == 2484)
        return 14;
    if (f >= 2412 && f < 2484)
        return (f - 2407) / 5;
    if (f >= 5955 && f <= 7115)
        return (f - 5950) / 5;
    if (f >= 5000 && f < 5955)
        return (f - 5000) / 5;
    return 0;
}

int WifiMonitor::recommendedFor(const QString &kind, double link_mbps, int signal_dbm)
{
    if (kind == QLatin1String("wired"))
        return 30;
    if (kind != QLatin1String("wifi"))
        return 0;
    if (link_mbps > 0.0)
        return std::clamp(static_cast<int>(link_mbps * 0.18 + 0.5), 5, 30);
    if (signal_dbm == 0)
        return 0;
    if (signal_dbm >= -60) return 25;
    if (signal_dbm >= -67) return 20;
    if (signal_dbm >= -75) return 15;
    if (signal_dbm >= -82) return 10;
    return 5;
}

int WifiMonitor::qualityFor(int recommended_mbps)
{
    if (recommended_mbps <= 0) return 0;
    if (recommended_mbps >= 25) return 4;
    if (recommended_mbps >= 18) return 3;
    if (recommended_mbps >= 12) return 2;
    return 1;
}

int WifiMonitor::recommendedBitrate() const
{
    return recommendedFor(kind_, link_mbps, signal_dbm);
}

int WifiMonitor::quality() const
{
    return qualityFor(recommendedBitrate());
}

QString WifiMonitor::defaultRouteInterface() const
{
    QFile route(QStringLiteral("/proc/net/route"));
    if (!route.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    route.readLine(); // header
    while (!route.atEnd()) {
        const QStringList cols = QString::fromLatin1(route.readLine()).split(QLatin1Char('\t'), Qt::SkipEmptyParts);
        if (cols.size() > 2 && cols[1] == QLatin1String("00000000"))
            return cols[0];
    }
    return {};
}

void WifiMonitor::poll()
{
    if (proc) // previous poll still running
        return;
    const QString route_iface = defaultRouteInterface();
    if (route_iface.isEmpty()) {
        kind_ = QStringLiteral("none");
        signal_dbm = 0; link_mbps = 0; frequency_mhz = 0; width_mhz = 0;
        rx_history.clear();
        emit updated();
        return;
    }
    if (!QFileInfo::exists(QStringLiteral("/sys/class/net/%1/wireless").arg(route_iface))) {
        kind_ = QStringLiteral("wired");
        signal_dbm = 0; link_mbps = 0; frequency_mhz = 0; width_mhz = 0;
        rx_history.clear();
        emit updated();
        return;
    }
    if (route_iface != iface) {
        iface = route_iface;
        rx_history.clear();
        connection_name.clear();
        scan_check_known = false;
        poll_count = 0;
    }
    kind_ = QStringLiteral("wifi");
    queue = { QStringLiteral("link"), QStringLiteral("info") };
    if (poll_count++ % kScanCheckEvery == 0)
        queue << QStringLiteral("conn") << QStringLiteral("bssid");
    runNext();
}

void WifiMonitor::runNext()
{
    if (queue.isEmpty()) {
        emit updated();
        return;
    }
    const QString step = queue.takeFirst();
    QString program;
    QStringList args;
    if (step == QLatin1String("link")) {
        program = QStringLiteral("iw"); args = { QStringLiteral("dev"), iface, QStringLiteral("link") };
    } else if (step == QLatin1String("info")) {
        program = QStringLiteral("iw"); args = { QStringLiteral("dev"), iface, QStringLiteral("info") };
    } else if (step == QLatin1String("conn")) {
        program = QStringLiteral("nmcli");
        args = { QStringLiteral("-t"), QStringLiteral("-f"), QStringLiteral("GENERAL.CONNECTION"), QStringLiteral("device"), QStringLiteral("show"), iface };
    } else { // bssid
        if (connection_name.isEmpty()) {
            scan_check_known = false;
            runNext();
            return;
        }
        program = QStringLiteral("nmcli");
        args = { QStringLiteral("-g"), QStringLiteral("802-11-wireless.bssid"), QStringLiteral("connection"), QStringLiteral("show"), connection_name };
    }

    proc = new QProcess(this);
    proc->setProcessChannelMode(QProcess::SeparateChannels);
    QTimer::singleShot(kStepTimeoutMs, proc, [p = proc]() { p->kill(); });
    connect(proc, &QProcess::finished, this, [this, step](int code, QProcess::ExitStatus status) {
        const QString out = QString::fromUtf8(proc->readAllStandardOutput());
        const bool ok = status == QProcess::NormalExit && code == 0;
        proc->deleteLater();
        proc = nullptr;
        if (step == QLatin1String("link")) {
            if (ok) parseLink(out);
        } else if (step == QLatin1String("info")) {
            if (ok) parseInfo(out);
        } else if (step == QLatin1String("conn")) {
            connection_name = ok ? out.section(QLatin1Char(':'), 1).trimmed() : QString();
        } else {
            scan_check_known = ok;
            // A locked profile (BSSID set) has nothing to roam to, so NetworkManager does
            // not run its 30 s background scans when the signal is weak.
            roaming_scans = ok && out.trimmed().isEmpty();
        }
        runNext();
    });
    connect(proc, &QProcess::errorOccurred, this, [this, step](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart || !proc)
            return;
        proc->deleteLater();
        proc = nullptr;
        if (step == QLatin1String("bssid") || step == QLatin1String("conn"))
            scan_check_known = false;
        runNext();
    });
    proc->start(program, args);
}

void WifiMonitor::parseLink(const QString &out)
{
    if (out.startsWith(QLatin1String("Not connected"))) {
        kind_ = QStringLiteral("none");
        signal_dbm = 0; link_mbps = 0; frequency_mhz = 0;
        rx_history.clear();
        return;
    }
    static const QRegularExpression freq_re(QStringLiteral("^\\s*freq:\\s*([0-9.]+)"), QRegularExpression::MultilineOption);
    static const QRegularExpression signal_re(QStringLiteral("^\\s*signal:\\s*(-?[0-9]+)\\s*dBm"), QRegularExpression::MultilineOption);
    static const QRegularExpression rx_re(QStringLiteral("^\\s*rx bitrate:\\s*([0-9.]+)\\s*MBit/s"), QRegularExpression::MultilineOption);
    static const QRegularExpression tx_re(QStringLiteral("^\\s*tx bitrate:\\s*([0-9.]+)\\s*MBit/s"), QRegularExpression::MultilineOption);
    auto m = freq_re.match(out);
    frequency_mhz = m.hasMatch() ? static_cast<int>(m.captured(1).toDouble() + 0.5) : 0;
    m = signal_re.match(out);
    signal_dbm = m.hasMatch() ? m.captured(1).toInt() : 0;
    double rate = 0.0;
    m = rx_re.match(out);
    if (m.hasMatch())
        rate = m.captured(1).toDouble();
    if (rate <= 0.0) {
        m = tx_re.match(out);
        if (m.hasMatch())
            rate = m.captured(1).toDouble();
    }
    if (rate > 0.0) {
        rx_history.append(rate);
        while (rx_history.size() > kRxHistory)
            rx_history.removeFirst();
    }
    if (rx_history.isEmpty()) {
        link_mbps = 0.0;
    } else {
        QVector<double> sorted = rx_history;
        std::sort(sorted.begin(), sorted.end());
        link_mbps = sorted[sorted.size() / 2];
    }
}

void WifiMonitor::parseInfo(const QString &out)
{
    static const QRegularExpression width_re(QStringLiteral("width:\\s*([0-9]+)\\s*MHz"));
    const auto m = width_re.match(out);
    width_mhz = m.hasMatch() ? m.captured(1).toInt() : 0;
}
