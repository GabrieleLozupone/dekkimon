#include "streambenchmark.h"
#include "qmlmainwindow.h"
#include "streamsession.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QMutexLocker>
#include <QTextStream>

#include <chiaki/takion.h>

#include <algorithm>
#include <cstring>

namespace {

QString primName(pl_color_primaries p)
{
    switch (p) {
    case PL_COLOR_PRIM_UNKNOWN: return QStringLiteral("unknown");
    case PL_COLOR_PRIM_BT_709: return QStringLiteral("bt709");
    case PL_COLOR_PRIM_BT_2020: return QStringLiteral("bt2020");
    case PL_COLOR_PRIM_DCI_P3: return QStringLiteral("dci-p3");
    case PL_COLOR_PRIM_DISPLAY_P3: return QStringLiteral("display-p3");
    default: return QStringLiteral("prim%1").arg(static_cast<int>(p));
    }
}

QString trcName(pl_color_transfer t)
{
    switch (t) {
    case PL_COLOR_TRC_UNKNOWN: return QStringLiteral("unknown");
    case PL_COLOR_TRC_SRGB: return QStringLiteral("srgb");
    case PL_COLOR_TRC_BT_1886: return QStringLiteral("bt1886");
    case PL_COLOR_TRC_GAMMA22: return QStringLiteral("gamma2.2");
    case PL_COLOR_TRC_LINEAR: return QStringLiteral("linear");
    case PL_COLOR_TRC_PQ: return QStringLiteral("pq");
    case PL_COLOR_TRC_HLG: return QStringLiteral("hlg");
    default: return QStringLiteral("trc%1").arg(static_cast<int>(t));
    }
}

QString describe(const pl_color_space &c)
{
    QString s = primName(c.primaries) + QLatin1Char('/') + trcName(c.transfer);
    if (c.hdr.max_luma > 0.0f || c.hdr.max_cll > 0.0f)
        s += QStringLiteral(" luma %1-%2 nits").arg(c.hdr.min_luma, 0, 'g', 3).arg(c.hdr.max_luma, 0, 'f', 0);
    if (c.hdr.max_cll > 0.0f || c.hdr.max_fall > 0.0f)
        s += QStringLiteral(" maxCLL %1 maxFALL %2").arg(c.hdr.max_cll, 0, 'f', 0).arg(c.hdr.max_fall, 0, 'f', 0);
    return s;
}

template <typename T> void append(QByteArray &key, const T &value)
{
    key.append(reinterpret_cast<const char *>(&value), sizeof(value));
}

void appendColor(QByteArray &key, const pl_color_space &c)
{
    append(key, c.primaries);
    append(key, c.transfer);
    append(key, c.hdr.min_luma);
    append(key, c.hdr.max_luma);
    append(key, c.hdr.max_cll);
    append(key, c.hdr.max_fall);
}

double percentile(QVector<double> values, double q)
{
    if (values.isEmpty())
        return 0.0;
    std::sort(values.begin(), values.end());
    const int index = std::clamp(static_cast<int>(q * (values.size() - 1) + 0.5), 0, static_cast<int>(values.size() - 1));
    return values[index];
}

} // namespace

StreamBenchmark::StreamBenchmark(QmlMainWindow *window)
    : QObject(window), window(window)
{
    timer.setInterval(1000);
    connect(&timer, &QTimer::timeout, this, &StreamBenchmark::sample);

    const QString path = qEnvironmentVariable("CHIAKI_BENCH_CSV");
    if (path.isEmpty())
        return;
    QDir().mkpath(QFileInfo(path).absolutePath());
    csv.setFileName(path);
    const bool fresh = !csv.exists() || csv.size() == 0;
    if (!csv.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        qCWarning(chiakiGui) << "Benchmark: cannot open" << path << csv.errorString();
        return;
    }
    // Columns after color_pipeline (all per second unless noted):
    //  target_bitrate, rtt, console_loss  last CONNECTIONQUALITY values from the console, as sent
    //  quality_reports                    CONNECTIONQUALITY messages received
    //  loss_measured_pct                  last 200 ms congestion window before the reported cap
    //  frames, src_units, fec_units       video frames started, their source and FEC units
    //  fec_recovered, fec_failed          frames repaired by FEC / lost despite FEC
    //  video_skipped, video_late          packets skipped by the reorder timeout / arriving after that
    //  arrived, shown, replaced           decoded frames, frames picked up by the renderer, overwritten
    //  arrive_bunched, show_late          decoder outputs < 4 ms apart, renderer pickups > 25 ms apart
    //  arrive_gap_max_ms, handoff_max_ms, show_gap_max_ms  largest gaps (see QmlMainWindow::PacingSnapshot)
    if (fresh)
        csv.write("wall_time,t_s,connected,bitrate_mbps,packet_loss_pct,frames_lost,frames_lost_delta,"
                  "dropped_frames,dropped_delta,queue_depth_avg,pending_frame_age_ms,color_pipeline,"
                  "target_bitrate,rtt,console_loss,quality_reports,loss_measured_pct,"
                  "frames,src_units,fec_units,fec_recovered,fec_failed,video_skipped,video_late,"
                  "arrived,shown,replaced,arrive_bunched,show_late,arrive_gap_max_ms,handoff_max_ms,show_gap_max_ms\n");
    csv.flush();
    qCInfo(chiakiGui) << "Benchmark: writing per-second stream stats to" << path;
}

StreamBenchmark::~StreamBenchmark()
{
    finishSession();
}

void StreamBenchmark::setSession(StreamSession *s)
{
    if (session == s)
        return;
    finishSession();
    session = s;
    if (!s)
        return;
    session_clock.start();
    bitrate_samples.clear();
    loss_samples.clear();
    base_frames_lost = last_frames_lost = s->GetFramesLost();
    dropped_total = 0;
    last_diag = s->GetStreamDiag();
    if (window)
        window->takePacingSnapshot();
    {
        QMutexLocker locker(&color_mutex);
        last_color_key.clear();
    }
    const QString config = QStringLiteral("packet_loss_max=%1 idr_on_fec_failure=%2 reorder_timeout_us=%3 overrides=%4")
        .arg(s->GetPacketLossMax() * 100.0, 0, 'f', 1)
        .arg(s->GetIdrOnFecFailure() ? 1 : 0)
        .arg(chiaki_takion_get_av_reorder_timeout_us())
        .arg(s->GetExperiment().isEmpty() ? QStringLiteral("none") : QStringLiteral("[%1]").arg(s->GetExperiment()));
    qCInfo(chiakiGui).noquote() << "Benchmark: stream config" << config;
    if (csv.isOpen()) {
        csv.write(QStringLiteral("# session start %1\n# config %2\n")
                      .arg(QDateTime::currentDateTime().toString(Qt::ISODate), config).toUtf8());
        timer.start();
    }
}

void StreamBenchmark::sample()
{
    if (!session || !csv.isOpen())
        return;
    const int frames_lost = session->GetFramesLost();
    const int dropped = window ? window->droppedFrames() : 0;
    dropped_total += dropped;
    const StreamSession::StreamDiag diag = session->GetStreamDiag();
    const QmlMainWindow::PacingSnapshot pace = window ? window->takePacingSnapshot() : QmlMainWindow::PacingSnapshot();
    // Counters restart from 0 when the stream reconnects; treat a decrease as a restart.
    auto delta = [](quint64 now, quint64 before) { return now >= before ? now - before : now; };
    const double bitrate = session->GetMeasuredBitrate();
    const double loss_pct = session->GetAveragePacketLoss() * 100.0;
    if (session->GetConnected() && bitrate > 0.0) {
        bitrate_samples.append(bitrate);
        loss_samples.append(loss_pct);
    }
    QString color;
    {
        QMutexLocker locker(&color_mutex);
        if (color_desc_pending) {
            color = color_desc;
            color_desc_pending = false;
        }
    }
    color.replace(QLatin1Char('"'), QLatin1Char('\''));
    QString row = QStringLiteral("%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,\"%12\"")
        .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs))
        .arg(session_clock.elapsed() / 1000.0, 0, 'f', 1)
        .arg(session->GetConnected() ? 1 : 0)
        .arg(bitrate, 0, 'f', 2)
        .arg(loss_pct, 0, 'f', 3)
        .arg(frames_lost - base_frames_lost)
        .arg(frames_lost - last_frames_lost)
        .arg(dropped_total)
        .arg(dropped)
        .arg(window ? window->queueDepthAverage() : 0.0, 0, 'f', 2)
        .arg(window ? window->pendingFrameAge() * 1000.0 : 0.0, 0, 'f', 1)
        .arg(color);
    row += QStringLiteral(",%1,%2,%3,%4,%5")
        .arg(diag.target_bitrate)
        .arg(diag.rtt, 0, 'f', 2)
        .arg(diag.console_loss)
        .arg(delta(diag.quality_reports, last_diag.quality_reports))
        .arg(diag.loss_measured * 100.0, 0, 'f', 2);
    row += QStringLiteral(",%1,%2,%3,%4,%5,%6,%7")
        .arg(delta(diag.frames, last_diag.frames))
        .arg(delta(diag.units_source, last_diag.units_source))
        .arg(delta(diag.units_fec, last_diag.units_fec))
        .arg(delta(diag.fec_recovered, last_diag.fec_recovered))
        .arg(delta(diag.fec_failed, last_diag.fec_failed))
        .arg(delta(diag.video_skipped, last_diag.video_skipped))
        .arg(delta(diag.video_late, last_diag.video_late));
    row += QStringLiteral(",%1,%2,%3,%4,%5,%6,%7,%8\n")
        .arg(pace.arrived)
        .arg(pace.shown)
        .arg(pace.replaced)
        .arg(pace.arrive_bunched)
        .arg(pace.show_late)
        .arg(pace.arrive_gap_max_ms, 0, 'f', 1)
        .arg(pace.handoff_max_ms, 0, 'f', 1)
        .arg(pace.show_gap_max_ms, 0, 'f', 1);
    csv.write(row.toUtf8());
    csv.flush();
    last_frames_lost = frames_lost;
    last_diag = diag;
}

void StreamBenchmark::finishSession()
{
    timer.stop();
    if (!session_clock.isValid())
        return;
    const double seconds = session_clock.elapsed() / 1000.0;
    session_clock.invalidate();
    if (bitrate_samples.isEmpty())
        return;
    double sum = 0.0, loss_sum = 0.0;
    for (double b : bitrate_samples) sum += b;
    for (double l : loss_samples) loss_sum += l;
    const QString summary = QStringLiteral(
        "Benchmark summary: %1 s, bitrate avg %2 / p05 %3 / p95 %4 Mbps, packet loss avg %5% / p95 %6%, "
        "frames lost %7, dropped frames %8")
        .arg(seconds, 0, 'f', 0)
        .arg(sum / bitrate_samples.size(), 0, 'f', 1)
        .arg(percentile(bitrate_samples, 0.05), 0, 'f', 1)
        .arg(percentile(bitrate_samples, 0.95), 0, 'f', 1)
        .arg(loss_sum / loss_samples.size(), 0, 'f', 2)
        .arg(percentile(loss_samples, 0.95), 0, 'f', 2)
        .arg(last_frames_lost - base_frames_lost)
        .arg(dropped_total);
    qCInfo(chiakiGui).noquote() << summary;
    if (csv.isOpen()) {
        csv.write(QStringLiteral("# %1\n").arg(summary).toUtf8());
        csv.flush();
    }
}

void StreamBenchmark::noteColorPipeline(const pl_color_space &source, const pl_color_space &swapchain,
                                        const pl_color_space &target, const pl_render_params &params,
                                        int target_trc, int target_prim, int target_peak, int target_contrast)
{
    const pl_color_map_params *cmap = params.color_map_params;
    const pl_tone_map_function *tone = cmap ? cmap->tone_mapping_function : nullptr;
    const pl_gamut_map_function *gamut = cmap ? cmap->gamut_mapping : nullptr;

    QByteArray key;
    key.reserve(160);
    appendColor(key, source);
    appendColor(key, swapchain);
    appendColor(key, target);
    append(key, tone);
    append(key, gamut);
    append(key, params.peak_detect_params);
    append(key, target_trc);
    append(key, target_prim);
    append(key, target_peak);
    append(key, target_contrast);

    QMutexLocker locker(&color_mutex);
    if (key == last_color_key)
        return;
    last_color_key = key;

    const bool hdr_source = source.transfer == PL_COLOR_TRC_PQ || source.transfer == PL_COLOR_TRC_HLG;
    const bool hdr_output = swapchain.transfer == PL_COLOR_TRC_PQ || swapchain.transfer == PL_COLOR_TRC_HLG;
    QString verdict;
    if (hdr_source && hdr_output)
        verdict = QStringLiteral("HDR passthrough");
    else if (hdr_source)
        verdict = QStringLiteral("HDR source tone-mapped to SDR output (display/compositor HDR is off)");
    else if (hdr_output)
        verdict = QStringLiteral("SDR source on HDR output");
    else
        verdict = QStringLiteral("SDR");

    color_desc = QStringLiteral("%1 | source %2 | swapchain %3 | target %4 | tonemap %5, gamut %6, peak detect %7 | overrides trc=%8 prim=%9 peak=%10 contrast=%11")
        .arg(verdict, describe(source), describe(swapchain), describe(target))
        .arg(tone && tone->name ? QString::fromUtf8(tone->name) : QStringLiteral("default"))
        .arg(gamut && gamut->name ? QString::fromUtf8(gamut->name) : QStringLiteral("default"))
        .arg(params.peak_detect_params ? QStringLiteral("on") : QStringLiteral("off"))
        .arg(target_trc).arg(target_prim).arg(target_peak).arg(target_contrast);
    color_desc_pending = true;
    qCInfo(chiakiGui).noquote() << "color pipeline:" << color_desc;
}
