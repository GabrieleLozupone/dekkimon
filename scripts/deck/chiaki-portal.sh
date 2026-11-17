#!/bin/bash
# Launcher for the native Steam Deck build (installed under ~/Applications/<app>).
# Keeps its own config/data/cache next to the binary.
#
# Developer measurements are opt-in: launch with DEKKIMON_BENCH=1 (e.g. Steam launch options
# "DEKKIMON_BENCH=1 %command%") to record per-second stream stats (bench/<time>.csv), the full
# log (bench/<time>.log) and, if scripts/dev/bench/*.sh were copied to <app>/dev/, system
# samples. See scripts/dev/bench/README.md.
set -u
APP_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
export XDG_CONFIG_HOME="$APP_DIR/config"
export XDG_DATA_HOME="$APP_DIR/data"
export XDG_CACHE_HOME="$APP_DIR/cache"
# Bundled libraries are only those the Deck does not ship; system libraries always win
# for everything else because they are not in this directory.
export LD_LIBRARY_PATH="$APP_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_QUICK_CONTROLS_STYLE=Material
# Qt logs to the journal when stderr is not a terminal; keep everything in the log file.
export QT_FORCE_STDERR_LOGGING=1
export QT_MESSAGE_PATTERN="%{time h:mm:ss.zzz} %{if-category}%{category}: %{endif}%{message}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
stamp="$(date +%Y%m%d-%H%M%S)"

if [ "${DEKKIMON_BENCH:-0}" = 1 ]; then
    LOG_DIR="$APP_DIR/bench"
    mkdir -p "$LOG_DIR"
    export CHIAKI_BENCH_CSV="${CHIAKI_BENCH_CSV:-$LOG_DIR/$stamp.csv}"
    # Streaming experiments: key=value overrides applied at every stream start (see
    # applyStreamExperiment in gui/src/streamsession.cpp). No file = saved settings only.
    [ -f "$APP_DIR/experiment.conf" ] && export CHIAKI_EXPERIMENT_FILE="$APP_DIR/experiment.conf"
    for ext in csv sys.csv ka; do
        ls -1t "$LOG_DIR"/*."$ext" 2>/dev/null | tail -n +41 | xargs -r rm -f
    done
else
    LOG_DIR="$APP_DIR/logs"
    mkdir -p "$LOG_DIR"
fi
# Keep the most recent runs: the stderr log also holds FFmpeg decoder messages that the
# in-app session log does not.
ls -1t "$LOG_DIR"/*.log 2>/dev/null | tail -n +21 | xargs -r rm -f
LOG="$LOG_DIR/$stamp.log"
{
    echo "# launch $stamp"
    echo "# gamescope HDR: ENABLE_GAMESCOPE_WSI=${ENABLE_GAMESCOPE_WSI:-unset} DXVK_HDR=${DXVK_HDR:-unset} STEAM_GAMESCOPE_HDR_SUPPORTED=${STEAM_GAMESCOPE_HDR_SUPPORTED:-unset}"
    echo "# args: $*"
    [ -n "${CHIAKI_EXPERIMENT_FILE:-}" ] && sed 's/^/# experiment.conf: /' "$CHIAKI_EXPERIMENT_FILE"
} >>"$LOG"

"$APP_DIR/bin/chiaki" "$@" >>"$LOG" 2>&1 &
chiaki_pid=$!
if [ "${DEKKIMON_BENCH:-0}" = 1 ]; then
    # Per-second Wi-Fi / thermal / clock / power samples next to the stream CSV.
    [ -x "$APP_DIR/dev/session_sampler.sh" ] && \
        "$APP_DIR/dev/session_sampler.sh" "$chiaki_pid" "$LOG_DIR/$stamp.sys.csv" >/dev/null 2>&1 &
    # Keep-alive A/B (only while the marker file exists).
    [ -f "$APP_DIR/ab-keepalive" ] && [ -x "$APP_DIR/dev/keepalive_ab.sh" ] && \
        "$APP_DIR/dev/keepalive_ab.sh" "$chiaki_pid" "$LOG_DIR/$stamp.ka" >/dev/null 2>&1 &
fi
trap 'kill -TERM "$chiaki_pid" 2>/dev/null' TERM INT HUP
wait "$chiaki_pid"
status=$?
# wait returns early when a trapped signal arrives; wait again for the real exit.
kill -0 "$chiaki_pid" 2>/dev/null && wait "$chiaki_pid" && status=$?
exit "$status"
