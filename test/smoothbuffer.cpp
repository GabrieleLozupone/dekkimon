// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

// Simulation tests for gui/include/smoothbuffer.h: a 60 fps stream over a network with
// Wi-Fi-like stalls, rendered by a 60 Hz loop. Build: see test/CMakeLists.txt (chiaki-smoothbuffer).

#include "smoothbuffer.h"

#include <cstdio>
#include <algorithm>
#include <cstdlib>
#include <random>
#include <vector>

static int live_frames = 0;
static void freeFrame(void *p) { live_frames--; delete static_cast<int64_t *>(p); }

#define CHECK(cond, ...) do { if(!(cond)) { std::fprintf(stderr, "FAIL %s:%d: ", __FILE__, __LINE__); std::fprintf(stderr, __VA_ARGS__); std::fprintf(stderr, "\n"); std::exit(1); } } while(0)

namespace {

constexpr int64_t kFrameUs = 16667;

struct Stall { int64_t at_us; int64_t len_us; };

struct Result
{
    std::vector<int64_t> show_gaps;   // time between consecutive shown frames
    std::vector<int64_t> pts_jumps;   // source frames advanced per shown frame
    std::vector<int64_t> delays;      // buffer delay sampled once per second
    int hitches = 0;                  // shown gaps > 40 ms
    SmoothBuffer::Stats total{};
};

// Frames are sent every 16.667 ms and arrive after 5 ms +- jitter; during a stall nothing
// arrives, then everything sent meanwhile arrives at its end. The renderer polls every vsync.
Result simulate(int64_t max_delay_us, int64_t duration_us, const std::vector<Stall> &stalls, int64_t jitter_us = 2000, unsigned seed = 1)
{
    SmoothBuffer buf(freeFrame);
    buf.setMaxDelay(max_delay_us);
    std::mt19937 rng(seed);
    std::uniform_int_distribution<int64_t> jit(0, jitter_us);

    struct Arrival { int64_t t; int64_t pts; };
    std::vector<Arrival> arrivals;
    for (int64_t pts = 0; pts < duration_us; pts += kFrameUs) {
        int64_t t = pts + 5000 + jit(rng);
        for (const auto &s : stalls)
            if (t >= s.at_us && t < s.at_us + s.len_us)
                t = s.at_us + s.len_us + (t - s.at_us) / 50; // burst, nearly back to back
        // the receiver reassembles and decodes in order: a frame can't overtake an older one
        if (!arrivals.empty())
            t = std::max(t, arrivals.back().t);
        arrivals.push_back({t, pts});
    }

    Result r;
    size_t next = 0;
    int64_t last_show = -1, last_pts = -1, next_sample = 1000000;
    for (int64_t now = 0; now < duration_us + 500000; now += kFrameUs) {
        // deliver everything that arrived before this vsync, then render
        while (next < arrivals.size() && arrivals[next].t <= now) {
            live_frames++;
            buf.push(new int64_t(arrivals[next].pts), arrivals[next].pts / 1e6, arrivals[next].t);
            next++;
        }
        if (void *f = buf.takeDue(now)) {
            const int64_t pts = *static_cast<int64_t *>(f);
            freeFrame(f);
            if (last_show >= 0) {
                r.show_gaps.push_back(now - last_show);
                r.pts_jumps.push_back((pts - last_pts + kFrameUs / 2) / kFrameUs);
                if (now - last_show > 40000) {
                    r.hitches++;
                    if (std::getenv("SB_DEBUG"))
                        std::printf("      [debug] hitch at %.2f s: %lld ms, delay %lld ms, pts jump %lld\n", now / 1e6,
                            (long long)(now - last_show) / 1000, (long long)buf.delay() / 1000, (long long)((pts - last_pts) / kFrameUs));
                }
            }
            CHECK(pts > last_pts, "frames shown out of order (%lld after %lld)", (long long)pts, (long long)last_pts);
            last_show = now;
            last_pts = pts;
        }
        if (now >= next_sample) {
            r.delays.push_back(buf.delay());
            next_sample += 1000000;
        }
        const auto s = buf.takeStats();
        r.total.late += s.late;
        r.total.grows += s.grows;
        r.total.shrinks += s.shrinks;
        r.total.rebases += s.rebases;
        r.total.dropped += s.dropped;
        r.total.delay_peak_us = std::max(r.total.delay_peak_us, s.delay_peak_us);
    }
    buf.clear();
    CHECK(live_frames == 0, "leaked %d frames", live_frames);
    return r;
}

std::vector<Stall> gtaLikeStalls(int64_t from_us, int64_t to_us, int64_t every_us, unsigned seed)
{
    // 110-150 ms holds every few seconds, like the 2026-11-27 GTA 6 session
    std::mt19937 rng(seed);
    std::uniform_int_distribution<int64_t> len(110000, 150000), gap(every_us / 2, every_us * 3 / 2);
    std::vector<Stall> out;
    for (int64_t t = from_us; t < to_us; t += gap(rng))
        out.push_back({t, len(rng)});
    return out;
}

void testCleanNetworkAddsNothing()
{
    const auto r = simulate(150000, 60000000, {});
    CHECK(r.hitches == 0, "clean network: %d hitches", r.hitches);
    CHECK(r.total.delay_peak_us == 0, "clean network grew the delay to %lld us", (long long)r.total.delay_peak_us);
    CHECK(r.total.dropped == 0, "clean network dropped %u frames", r.total.dropped);
}

void testOffBehavesLikeDirect()
{
    const auto stalls = gtaLikeStalls(5000000, 60000000, 6000000, 7);
    const auto r = simulate(0, 60000000, stalls);
    CHECK(r.total.delay_peak_us == 0, "off: delay grew");
    CHECK(r.hitches >= (int)stalls.size() * 8 / 10, "off: expected a hitch per stall (%d for %zu)", r.hitches, stalls.size());
}

void testAbsorbsRepeatedStalls()
{
    const auto stalls = gtaLikeStalls(5000000, 120000000, 6000000, 3);
    const auto off = simulate(0, 120000000, stalls);
    const auto on = simulate(150000, 120000000, stalls);
    std::printf("  repeated 110-150 ms stalls: %zu stalls, hitches off=%d on=%d, delay peak %lld ms, dropped %u\n",
        stalls.size(), off.hitches, on.hitches, (long long)on.total.delay_peak_us / 1000, on.total.dropped);
    for (size_t i = 0; i < on.show_gaps.size(); i++)
        if (on.show_gaps[i] > 40000)
            std::printf("    hitch %lld ms\n", (long long)on.show_gaps[i] / 1000);
    CHECK(on.hitches <= 3, "buffer should hide all but the first stalls (%d hitches)", on.hitches);
    CHECK(on.total.delay_peak_us <= 150000, "delay above the cap");
    // after the delay settled, every shown frame advances exactly one source frame
    size_t jumps = 0;
    for (size_t i = on.pts_jumps.size() / 4; i < on.pts_jumps.size(); i++)
        if (on.pts_jumps[i] != 1)
            jumps++;
    CHECK(jumps <= 3, "%zu skipped/repeated frames after settling", jumps);
}

void testShrinksAfterCalm()
{
    // a bad minute, then two calm minutes: the delay must come back down to ~0
    const auto stalls = gtaLikeStalls(5000000, 60000000, 6000000, 5);
    const auto r = simulate(150000, 180000000, stalls);
    CHECK(r.total.delay_peak_us >= 100000, "delay never grew (%lld)", (long long)r.total.delay_peak_us);
    CHECK(r.delays.back() == 0, "delay did not return to 0 (%lld us)", (long long)r.delays.back());
    CHECK(r.hitches <= 4, "%d hitches", r.hitches);
    std::printf("  shrink: peak %lld ms, final %lld ms, shrinks %u, dropped %u\n",
        (long long)r.total.delay_peak_us / 1000, (long long)r.delays.back() / 1000, r.total.shrinks, r.total.dropped);
}

void testLongStallSkipsAhead()
{
    // 400 ms hold: too long to hide; afterwards playback must not lag 400 ms behind
    const auto r = simulate(150000, 20000000, {{5000000, 400000}});
    CHECK(r.total.rebases == 1, "expected one re-anchor, got %u", r.total.rebases);
    CHECK(r.hitches >= 1, "a 400 ms stall cannot be hidden");
    // after it the delay is at most the cap: frames keep coming every vsync
    int late_after = 0;
    for (size_t i = r.show_gaps.size() / 2; i < r.show_gaps.size(); i++)
        if (r.show_gaps[i] > 40000)
            late_after++;
    CHECK(late_after == 0, "%d hitches after recovering", late_after);
}

void testConsolePauseDoesNotGrow()
{
    // the console stops sending for a while (static screen) and resumes at the normal pace,
    // without a backlog: nothing to buffer for, the delay must stay at 0
    SmoothBuffer buf(freeFrame);
    buf.setMaxDelay(150000);
    int64_t pts = 0, t = 5000;
    for (int i = 0; i < 1200; i++) {
        if (i == 300)
            t += 1500000; // 1.5 s pause; the console's timeline continues where it stopped
        if (i == 700)
            t += 90000;   // and a short one
        live_frames++;
        buf.push(new int64_t(pts), pts / 1e6, t);
        if (void *f = buf.takeDue(t))
            freeFrame(f);
        pts += kFrameUs;
        t += kFrameUs;
    }
    CHECK(buf.delay() == 0, "console pause grew the delay to %lld us", (long long)buf.delay());
    buf.clear();
    CHECK(live_frames == 0, "leak");
}

// 2026-11-27 13:37 session on the Deck: GTA 6 below 60 fps for ~13% of the seconds (the console
// sends 58-59 frames, its timeline stays contiguous) and ordinary Wi-Fi jitter, no stall. The
// first buffer version read the drift as network lateness and climbed to 150 ms. Then a real
// stall: the delay must come back down soon after it, even while the game keeps dipping.
void testSlowGameIsNotNetworkLateness()
{
    SmoothBuffer buf(freeFrame);
    buf.setMaxDelay(150000);
    std::mt19937 rng(11);
    std::uniform_real_distribution<double> u(0, 1);
    std::uniform_int_distribution<int64_t> jit(0, 12000);
    int64_t send = 0, pts = 0, last = 0, sec_end = 1000000, peak = 0;
    double interval = 16667;
    bool stalled = false;
    int64_t after_stall_peak_until = 0;
    while (send < 240000000) {
        if (send >= sec_end) {
            const double r = u(rng);
            interval = r < 0.03 ? 1e6 / 58 : r < 0.13 ? 1e6 / 59 : 16667;
            sec_end += 1000000;
        }
        int64_t t = send + 5000 + jit(rng);
        if (!stalled && send >= 120000000) { // one 130 ms Wi-Fi hold at 2 minutes
            t += 130000;
            stalled = true;
            after_stall_peak_until = t;
        }
        t = std::max(t, last + 300);
        last = t;
        live_frames++;
        buf.push(new int64_t(pts), pts / 1e6, t);
        if (void *f = buf.takeDue(t))
            freeFrame(f);
        if (send < 120000000)
            peak = std::max(peak, buf.delay());
        if (after_stall_peak_until && t > after_stall_peak_until + 40000000)
            CHECK(buf.delay() == 0, "delay %lld ms still up 40 s after the stall", (long long)buf.delay() / 1000);
        pts += kFrameUs;
        send += static_cast<int64_t>(interval);
    }
    CHECK(peak == 0, "game below 60 fps grew the delay to %lld ms without any stall", (long long)peak / 1000);
    buf.clear();
    CHECK(live_frames == 0, "leak");
}

void testRespectsSmallerCap()
{
    const auto stalls = gtaLikeStalls(5000000, 60000000, 6000000, 9);
    const auto r = simulate(100000, 60000000, stalls);
    CHECK(r.total.delay_peak_us <= 100000, "delay %lld above the 100 ms cap", (long long)r.total.delay_peak_us);
}

void testBaselineFollowsSlowerPath()
{
    // the network becomes 60 ms slower for good: no hitch storm, and the buffer delay
    // must not stay inflated by the step (the baseline moves instead)
    SmoothBuffer buf(freeFrame);
    buf.setMaxDelay(150000);
    int64_t now = 0;
    for (int64_t pts = 0; pts < 120000000; pts += kFrameUs) {
        const int64_t t = pts + (pts < 10000000 ? 5000 : 65000);
        live_frames++;
        buf.push(new int64_t(pts), pts / 1e6, t);
        now = t;
        if (void *f = buf.takeDue(now))
            freeFrame(f);
    }
    CHECK(buf.delay() < 20000, "delay stuck at %lld us after a permanent latency step", (long long)buf.delay());
    buf.clear();
    CHECK(live_frames == 0, "leak");
}

void testTimelineResetKeepsOrder()
{
    SmoothBuffer buf(freeFrame);
    buf.setMaxDelay(150000);
    live_frames += 3;
    buf.push(new int64_t(1), 10.0, 1000);
    buf.push(new int64_t(2), 10.016, 18000);
    buf.push(new int64_t(3), 0.0, 20000); // decoder restarted its timeline
    int skipped = 0;
    void *f = buf.takeDue(30000, &skipped);
    CHECK(f && *static_cast<int64_t *>(f) == 3, "newest frame after reset not shown");
    freeFrame(f);
    CHECK(skipped == 2, "expected 2 skipped, got %d", skipped);
    CHECK(live_frames == 0, "leak");
}

} // namespace

int main()
{
    testCleanNetworkAddsNothing();
    testOffBehavesLikeDirect();
    testAbsorbsRepeatedStalls();
    testShrinksAfterCalm();
    testLongStallSkipsAhead();
    testConsolePauseDoesNotGrow();
    testSlowGameIsNotNetworkLateness();
    testRespectsSmallerCap();
    testBaselineFollowsSlowerPath();
    testTimelineResetKeepsOrder();
    std::printf("smoothbuffer: all tests passed\n");
    return 0;
}
