// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#ifndef CHIAKI_SMOOTHBUFFER_H
#define CHIAKI_SMOOTHBUFFER_H

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <deque>
#include <mutex>

// Adaptive playout buffer for the direct render path ("smooth buffer").
//
// Wi-Fi often holds video back for 100-200 ms and then delivers the late frames in one burst.
// Shown as they arrive, that is a freeze followed by a jump. This buffer delays every frame by
// a target D so that frames are shown at the pace the console sent them; D adapts:
//
//  - Each frame's expected arrival is baseline + pts (pts = the console's frame timeline). The
//    baseline is the fastest delivery among the last base_frames frames (about half a second),
//    so a steady network delay costs nothing and D only covers sudden lateness on top of it.
//    The short window matters: when the game runs below 60 fps the console sends fewer frames
//    while its timeline stays contiguous, so frames drift later and later. That drift is
//    gradual and the baseline follows it; only a sudden hold (a network stall) shows up as
//    lateness.
//  - A frame later than D by more than grow_threshold (1.5 frames), after a single gap at least
//    that much longer than the console's frame spacing, grows D to that lateness plus 25%
//    headroom, up to max_delay, but only once the next frame confirms a network stall by
//    arriving right behind it (the backlog). A console pause or a dropped game frame is
//    followed by frames at the normal pace, and D stays as it is.
//    The first stall of a bad period is still visible; similar stalls after it are absorbed.
//  - A stall longer than max_delay can't be absorbed: the timeline is re-anchored (and D goes
//    to max_delay if it was a network stall), so playback skips ahead instead of lagging behind.
//  - After calm_before_shrink without growth, D shrinks one frame every shrink_every, never
//    below the largest stall seen in the last floor_window. Each shrink drops one frame.
//
// With max_delay 0 (off) or D 0, every frame is due on arrival: identical to showing it at once.
// Frames are opaque pointers released with free_fn. Thread-safe.
class SmoothBuffer
{
public:
    using FreeFn = void (*)(void *);

    struct Config
    {
        int64_t max_delay_us = 150000;
        int64_t margin_us = 4000;
        int64_t grow_threshold_us = 25000; // a hold shorter than 1.5 frames is barely visible
        int64_t burst_gap_us = 10000;   // decoder outputs closer than this = backlog after a stall
        int64_t calm_before_shrink_us = 15000000;
        int64_t shrink_every_us = 1000000;
        int64_t shrink_step_us = 16667;
        size_t base_frames = 30;
        int64_t floor_window_us = 20000000;
        int64_t due_tolerance_us = 4000;
        size_t max_frames = 32;
    };

    // Counters since the previous takeStats(); delay values are current/peak in that interval.
    struct Stats
    {
        int64_t delay_us = 0;
        int64_t delay_peak_us = 0;
        uint32_t late = 0;      // frames that arrived after their slot (visible hitch)
        uint32_t grows = 0;
        uint32_t shrinks = 0;
        uint32_t rebases = 0;   // stalls longer than max_delay
        uint32_t dropped = 0;   // frames skipped (shrink, catch-up or overflow)
    };

    explicit SmoothBuffer(FreeFn free_fn) : free_fn(free_fn) {}
    ~SmoothBuffer() { clear(); }
    SmoothBuffer(const SmoothBuffer &) = delete;
    SmoothBuffer &operator=(const SmoothBuffer &) = delete;

    void setMaxDelay(int64_t max_delay_us)
    {
        std::lock_guard<std::mutex> lock(mutex);
        cfg.max_delay_us = std::max<int64_t>(0, max_delay_us);
        delay_us = std::min(delay_us, cfg.max_delay_us);
    }

    void setConfig(const Config &c)
    {
        std::lock_guard<std::mutex> lock(mutex);
        cfg = c;
        delay_us = std::min(delay_us, cfg.max_delay_us);
    }

    int64_t maxDelay() const
    {
        std::lock_guard<std::mutex> lock(mutex);
        return cfg.max_delay_us;
    }

    // Frees queued frames and forgets the timeline (new session, decoder reset).
    void clear()
    {
        std::lock_guard<std::mutex> lock(mutex);
        clearLocked();
    }

    void push(void *frame, double pts_s, int64_t arrival_us)
    {
        std::lock_guard<std::mutex> lock(mutex);
        const int64_t pts_us = std::isfinite(pts_s) ? static_cast<int64_t>(std::llround(pts_s * 1e6)) : 0;
        int64_t fixed_due_us = -1;

        if (cfg.max_delay_us <= 0) {
            delay_us = 0;
            have_base = false;
            fixed_due_us = arrival_us;
        } else {
            const int64_t offset = arrival_us - pts_us;
            // how much longer than the console's frame spacing this frame took after the last
            // one: a stall is one sudden gap, a slow game or jitter spread over many frames
            const int64_t gap_excess = have_base && pts_us > last_pts_us
                ? (arrival_us - last_arrival_us) - (pts_us - last_pts_us) : 0;
            if (!have_base || pts_us <= last_pts_us) {
                // first frame or a decoder timeline reset: frames still queued keep their slot
                freezeQueuedDueLocked();
                rebaseLocked(offset);
                last_shrink_us = arrival_us;
            }
            last_pts_us = pts_us;

            // lateness against the fastest of the previous base_frames frames
            const int64_t lateness = std::max<int64_t>(0, offset - base_us);

            // the frame after a late one tells a network stall (backlog right behind it) from
            // a console pause (normal pace)
            if (pending_delay_us > 0) {
                if (arrival_us - last_arrival_us < cfg.burst_gap_us && pending_delay_us > delay_us) {
                    delay_us = pending_delay_us;
                    stats.grows++;
                    last_grow_us = arrival_us;
                }
                pending_delay_us = 0;
            }

            if (lateness > cfg.max_delay_us) {
                // too long to hide: re-anchor here; a burst that follows pulls the baseline back,
                // so playback skips to the right frame instead of lagging behind
                freezeQueuedDueLocked();
                rebaseLocked(offset);
                stats.rebases++;
                stats.late++;
                pending_delay_us = cfg.max_delay_us;
                recordStallLocked(arrival_us, cfg.max_delay_us);
            } else {
                if (lateness > delay_us + cfg.grow_threshold_us && gap_excess > cfg.grow_threshold_us) {
                    stats.late++;
                    // 25% headroom: the next stall of a bad stretch is often a bit longer
                    pending_delay_us = std::min(cfg.max_delay_us, lateness + lateness / 4 + cfg.margin_us);
                }
                if (lateness > cfg.grow_threshold_us)
                    recordStallLocked(arrival_us, lateness);
                addOffsetLocked(offset);
            }

            maybeShrinkLocked(arrival_us);
            last_arrival_us = arrival_us;
        }

        stats.delay_peak_us = std::max(stats.delay_peak_us, delay_us);
        queue.push_back({frame, pts_us, fixed_due_us});
        while (queue.size() > cfg.max_frames) {
            free_fn(queue.front().frame);
            queue.pop_front();
            stats.dropped++;
        }
    }

    // Returns the newest frame that is due at now_us (caller owns it) or nullptr. Older due
    // frames are freed; their count is added to *skipped.
    void *takeDue(int64_t now_us, int *skipped = nullptr)
    {
        std::lock_guard<std::mutex> lock(mutex);
        void *out = nullptr;
        int n = 0;
        while (!queue.empty() && dueLocked(queue.front()) <= now_us + cfg.due_tolerance_us) {
            if (out) {
                free_fn(out);
                n++;
            }
            out = queue.front().frame;
            queue.pop_front();
        }
        stats.dropped += n;
        if (skipped)
            *skipped = n;
        return out;
    }

    bool hasDue(int64_t now_us) const
    {
        std::lock_guard<std::mutex> lock(mutex);
        return !queue.empty() && dueLocked(queue.front()) <= now_us + cfg.due_tolerance_us;
    }

    // Due time of the oldest queued frame, or -1 when empty.
    int64_t nextDue() const
    {
        std::lock_guard<std::mutex> lock(mutex);
        return queue.empty() ? -1 : dueLocked(queue.front());
    }

    int64_t delay() const
    {
        std::lock_guard<std::mutex> lock(mutex);
        return delay_us;
    }

    Stats takeStats()
    {
        std::lock_guard<std::mutex> lock(mutex);
        Stats s = stats;
        s.delay_us = delay_us;
        s.delay_peak_us = std::max(s.delay_peak_us, delay_us);
        stats = {};
        return s;
    }

private:
    // Due times follow the current baseline and delay (computed on demand), except for frames
    // queued before a re-anchor, which keep the slot they had (fixed_due_us >= 0).
    struct Entry
    {
        void *frame;
        int64_t pts_us;
        int64_t fixed_due_us;
    };

    int64_t dueLocked(const Entry &e) const
    {
        if (e.fixed_due_us >= 0 || !have_base)
            return e.fixed_due_us >= 0 ? e.fixed_due_us : 0;
        return base_us + e.pts_us + delay_us;
    }

    void freezeQueuedDueLocked()
    {
        for (auto &e : queue)
            e.fixed_due_us = dueLocked(e);
    }
    struct Stall
    {
        int64_t at_us;
        int64_t lateness_us;
    };

    void clearLocked()
    {
        for (auto &e : queue)
            free_fn(e.frame);
        queue.clear();
        have_base = false;
        delay_us = 0;
        offsets.clear();
        stalls.clear();
        last_grow_us = last_shrink_us = 0;
        last_arrival_us = 0;
        pending_delay_us = 0;
    }

    void rebaseLocked(int64_t offset)
    {
        offsets.clear();
        offsets.push_back(offset);
        base_us = offset;
        have_base = true;
    }

    // Keeps the last base_frames offsets (arrival - pts); the baseline is their minimum.
    void addOffsetLocked(int64_t offset)
    {
        offsets.push_back(offset);
        while (offsets.size() > cfg.base_frames)
            offsets.pop_front();
        base_us = *std::min_element(offsets.begin(), offsets.end());
    }

    void recordStallLocked(int64_t now_us, int64_t lateness)
    {
        stalls.push_back({now_us, lateness});
        while (!stalls.empty() && now_us - stalls.front().at_us > cfg.floor_window_us)
            stalls.pop_front();
    }

    void maybeShrinkLocked(int64_t now_us)
    {
        if (delay_us <= 0)
            return;
        if (now_us - last_grow_us < cfg.calm_before_shrink_us || now_us - last_shrink_us < cfg.shrink_every_us)
            return;
        while (!stalls.empty() && now_us - stalls.front().at_us > cfg.floor_window_us)
            stalls.pop_front();
        int64_t floor = 0;
        for (auto &st : stalls)
            floor = std::max(floor, st.lateness_us + cfg.margin_us);
        const int64_t target = std::max<int64_t>(floor, delay_us - cfg.shrink_step_us);
        if (target < delay_us) {
            delay_us = target < cfg.margin_us ? 0 : target;
            stats.shrinks++;
        }
        last_shrink_us = now_us;
    }

    mutable std::mutex mutex;
    FreeFn free_fn;
    Config cfg;
    std::deque<Entry> queue;
    std::deque<int64_t> offsets;
    std::deque<Stall> stalls;
    bool have_base = false;
    int64_t base_us = 0;
    int64_t last_pts_us = 0;
    int64_t delay_us = 0;
    int64_t last_grow_us = 0;
    int64_t last_shrink_us = 0;
    int64_t last_arrival_us = 0;
    int64_t pending_delay_us = 0;
    Stats stats;
};

#endif // CHIAKI_SMOOTHBUFFER_H
