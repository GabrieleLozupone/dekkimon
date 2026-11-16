#ifndef CHIAKI_WIFIMONITOR_H
#define CHIAKI_WIFIMONITOR_H

#include <QObject>
#include <QProcess>
#include <QString>
#include <QTimer>
#include <QVector>

// Live link status for the home screen and menus: how the device is connected and what
// stream quality to expect there. Linux only (reads `iw`, `nmcli`, /proc and /sys); on other
// systems, or when the tools are missing, kind stays "unknown" and the UI hides itself.
//
// Polls only while `active` is true (set by the views that show it), every 3 s. The streaming
// estimate comes from the radio's receive rate (median of the last samples), because that is
// what limits video delivery; signal strength alone is shown for reference. Thresholds come
// from measured sessions on a Steam Deck OLED (docs/steam-deck-smooth-streaming.md):
// 40 MHz / ~100 Mbit/s carried 18 Mbps cleanly but stuttered at 25; 80 MHz / ~290 Mbit/s
// carried 25 Mbps cleanly even at -85 dBm. A stream should stay under ~18% of the link rate.
class WifiMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QString kind READ kind NOTIFY updated)               // wifi, wired, none, unknown
    Q_PROPERTY(int signalDbm READ signalDbm NOTIFY updated)          // 0 = unknown
    Q_PROPERTY(double linkMbps READ linkMbps NOTIFY updated)         // receive rate, Mbit/s
    Q_PROPERTY(int frequencyMhz READ frequencyMhz NOTIFY updated)
    Q_PROPERTY(int channel READ channel NOTIFY updated)
    Q_PROPERTY(int widthMhz READ widthMhz NOTIFY updated)            // 0 = unknown
    Q_PROPERTY(int quality READ quality NOTIFY updated)              // 0 none/unknown, 1 weak .. 4 excellent
    Q_PROPERTY(int recommendedBitrate READ recommendedBitrate NOTIFY updated) // Mbps for 1080p60
    Q_PROPERTY(bool roamingScans READ roamingScans NOTIFY updated)   // profile not locked: scans when weak
    Q_PROPERTY(bool scanCheckKnown READ scanCheckKnown NOTIFY updated)

public:
    explicit WifiMonitor(QObject *parent = nullptr);

    bool active() const { return is_active; }
    void setActive(bool active);
    QString kind() const { return kind_; }
    int signalDbm() const { return signal_dbm; }
    double linkMbps() const { return link_mbps; }
    int frequencyMhz() const { return frequency_mhz; }
    int channel() const;
    int widthMhz() const { return width_mhz; }
    int quality() const;
    int recommendedBitrate() const;
    bool roamingScans() const { return roaming_scans; }
    bool scanCheckKnown() const { return scan_check_known; }

    // Exposed for tests: the estimate from a link rate (Mbit/s, 0 = unknown) and signal.
    static int recommendedFor(const QString &kind, double link_mbps, int signal_dbm);
    static int qualityFor(int recommended_mbps);

signals:
    void activeChanged();
    void updated();

private:
    void poll();
    void runNext();
    void parseLink(const QString &out);
    void parseInfo(const QString &out);
    QString defaultRouteInterface() const;

    bool is_active = false;
    QTimer timer;
    QProcess *proc = nullptr;
    QStringList queue;            // pending steps of the current poll
    QString iface;
    QString connection_name;
    int poll_count = 0;

    QString kind_ = QStringLiteral("unknown");
    int signal_dbm = 0;
    double link_mbps = 0.0;
    int frequency_mhz = 0;
    int width_mhz = 0;
    bool roaming_scans = false;
    bool scan_check_known = false;
    QVector<double> rx_history;
};

#endif // CHIAKI_WIFIMONITOR_H
