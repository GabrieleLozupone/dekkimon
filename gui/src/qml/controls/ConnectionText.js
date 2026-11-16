.pragma library
// Shared wording for the connection indicator (home corner, menu card, Connection page).
// `w` is Chiaki.wifi (WifiMonitor), `s` is Chiaki.settings.

function shown(w) {
    return !!w && (w.kind === "wifi" || w.kind === "wired" || w.kind === "none");
}

function qualityLabel(w) {
    if (!w) return "";
    if (w.kind === "wired") return qsTr("Wired");
    if (w.kind === "none") return qsTr("Offline");
    if (w.kind !== "wifi") return "";
    return [qsTr("Checking…"), qsTr("Weak"), qsTr("Fair"), qsTr("Good"), qsTr("Excellent")][Math.max(0, Math.min(4, w.quality))];
}

function bars(w) {
    if (!w) return 0;
    if (w.kind === "wired") return 4;
    return w.kind === "wifi" ? w.quality : 0;
}

function verdict(w) {
    if (!w) return "";
    if (w.kind === "wired")
        return qsTr("Wired connection: ready for 1080p60 at up to %1 Mbps.").arg(w.recommendedBitrate);
    if (w.kind === "none")
        return qsTr("Not connected to a network.");
    if (w.kind !== "wifi")
        return "";
    switch (w.quality) {
    case 4: return qsTr("Ready for 1080p60 at up to %1 Mbps, sharp even in fast motion.").arg(w.recommendedBitrate);
    case 3: return qsTr("Ready for smooth 1080p60 at up to %1 Mbps.").arg(w.recommendedBitrate);
    case 2: return qsTr("1080p60 works at up to %1 Mbps. Expect occasional hitches in fast scenes.").arg(w.recommendedBitrate);
    case 1: return qsTr("Expect stutter here. Use %1 Mbps or less, or move closer to the router.").arg(w.recommendedBitrate);
    }
    return qsTr("Measuring the connection…");
}

// Short form for the menu card: "Good · up to 20 Mbps".
function summary(w) {
    const label = qualityLabel(w);
    if (!w || (w.kind !== "wifi" && w.kind !== "wired") || w.recommendedBitrate <= 0)
        return label;
    return qsTr("%1 · up to %2 Mbps").arg(label).arg(w.recommendedBitrate);
}

// The bitrate the user streams at on a local PS5, in Mbps (0 in settings = automatic).
function bitrateSetting(s) {
    if (!s) return 0;
    const kbps = s.bitrateLocalPS5 || 0;
    if (kbps > 0) return Math.round(kbps / 1000);
    return ({ 1: 2, 2: 6, 3: 10, 4: 15 })[s.resolutionLocalPS5] || 15;
}

function band(w) {
    if (!w || !w.frequencyMhz) return "";
    const f = w.frequencyMhz;
    const name = f < 3000 ? "2.4 GHz" : f < 5925 ? "5 GHz" : "6 GHz";
    const parts = [name];
    if (w.channel) parts.push(qsTr("channel %1").arg(w.channel));
    if (w.widthMhz) parts.push(qsTr("%1 MHz").arg(w.widthMhz));
    return parts.join(" · ");
}

// Advice that applies right now, most useful first.
function tips(w, s) {
    const out = [];
    if (!w || w.kind !== "wifi") return out;
    const f = w.frequencyMhz;
    if (f > 0 && f < 3000)
        out.push(qsTr("You are on 2.4 GHz. Connect to your router's 5 GHz network: it is much faster and less crowded."));
    if (f >= 5000 && w.widthMhz > 0 && w.widthMhz < 80)
        out.push(qsTr("Your router uses a %1 MHz channel. In its 5 GHz settings, choose channel 36–48 and 80 MHz bandwidth to roughly double the room for video.").arg(w.widthMhz));
    const mine = bitrateSetting(s);
    if (w.recommendedBitrate > 0 && mine > w.recommendedBitrate + 2)
        out.push(qsTr("Your bitrate (%1 Mbps) is higher than this spot supports (%2 Mbps). Lower it in Settings › Streaming, or move closer to the router.").arg(mine).arg(w.recommendedBitrate));
    if (w.scanCheckKnown && w.roamingScans && w.signalDbm !== 0 && w.signalDbm < -67)
        out.push(qsTr("Background Wi-Fi scans are on. Below -70 dBm SteamOS scans every 30 seconds, which causes a few seconds of stutter each time. Locking the Wi-Fi connection to your router stops them (see the streaming guide)."));
    if (w.signalDbm !== 0 && w.signalDbm < -80)
        out.push(qsTr("The signal is weak here (%1 dBm). Moving closer to the router, or out of the way of walls, helps the most.").arg(w.signalDbm));
    return out;
}

// What each level needs, for the reference table (from WifiMonitor's 18 % rule).
function levels() {
    return [
        { label: qsTr("Excellent"), level: 4, link: qsTr("140+ Mbit/s"), bitrate: qsTr("25–30 Mbps") },
        { label: qsTr("Good"), level: 3, link: qsTr("100+ Mbit/s"), bitrate: qsTr("18–24 Mbps") },
        { label: qsTr("Fair"), level: 2, link: qsTr("65+ Mbit/s"), bitrate: qsTr("12–17 Mbps") },
        { label: qsTr("Weak"), level: 1, link: qsTr("under 65 Mbit/s"), bitrate: qsTr("under 12 Mbps") }
    ];
}
