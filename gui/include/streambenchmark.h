#ifndef CHIAKI_STREAMBENCHMARK_H
#define CHIAKI_STREAMBENCHMARK_H

#include <QByteArray>
#include <QElapsedTimer>
#include <QFile>
#include <QMutex>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QTimer>
#include <QVector>

#include <libplacebo/colorspace.h>
#include <libplacebo/renderer.h>

#include "streamsession.h"

class QmlMainWindow;

// Stream telemetry for tuning on a device.
//  * Colour pipeline: whenever the source colour space, the negotiated swapchain colour
//    space, the render target or the tone-mapping setup changes, one "color pipeline:" line
//    is logged. This shows whether HDR10 actually reaches the display (gamescope HDR on/off)
//    and which peak brightness libplacebo maps to.
//  * CSV (opt-in, CHIAKI_BENCH_CSV=/path/file.csv): one row per second while a session is
//    running with bitrate, packet loss, lost/dropped frames and render queue state, plus a
//    per-session summary line in the log when the session ends.
class StreamBenchmark : public QObject
{
    Q_OBJECT

public:
    explicit StreamBenchmark(QmlMainWindow *window);
    ~StreamBenchmark() override;

    void setSession(StreamSession *session);

    // Called from the render thread for every rendered frame; cheap unless something changed.
    void noteColorPipeline(const pl_color_space &source, const pl_color_space &swapchain,
                           const pl_color_space &target, const pl_render_params &params,
                           int target_trc, int target_prim, int target_peak, int target_contrast);

private:
    void sample();
    void finishSession();

    QmlMainWindow *window = nullptr;
    QPointer<StreamSession> session;
    QTimer timer;
    QFile csv;
    QElapsedTimer session_clock;

    QMutex color_mutex;
    QByteArray last_color_key;
    QString color_desc;
    bool color_desc_pending = false;

    int base_frames_lost = 0;
    int last_frames_lost = 0;
    int dropped_total = 0; // QmlMainWindow::droppedFrames() is already a per-second count
    StreamSession::StreamDiag last_diag;
    QVector<double> bitrate_samples;
    QVector<double> loss_samples;
};

#endif // CHIAKI_STREAMBENCHMARK_H
