#!/bin/bash
# A/B test for the "idle link" hypothesis: does light constant downlink traffic on the Wi-Fi
# link prevent loss bursts when a stream resumes after a static scene?
#   keepalive_ab.sh <chiaki-pid> <state-file> [block-seconds]
# Alternates ON/OFF blocks (default 240 s, random first block) until chiaki exits.
# ON = ICMP echo to the default gateway every 15 ms (16-byte payload, ~5 kB/s each way); the
# replies keep the access point transmitting to the Deck so its rate control and power state
# stay active. The current state (1/0) is written to <state-file>; session_sampler.sh copies
# it into the "keepalive" column of bench/<stamp>.sys.csv. Started by the launcher (DEKKIMON_BENCH=1) only
# when ~/Applications/dekkimon/ab-keepalive exists.
set -u
PID="$1"; STATE="$2"; BLOCK="${3:-240}"
GW="$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')"
ping_pid=""
cleanup() { [ -n "$ping_pid" ] && kill "$ping_pid" 2>/dev/null; echo 0 >"$STATE"; exit 0; }
trap cleanup TERM INT HUP EXIT

on=$((RANDOM % 2))
while kill -0 "$PID" 2>/dev/null; do
    echo "$on" >"$STATE"
    if [ "$on" = 1 ] && [ -n "$GW" ]; then
        ping -i 0.015 -s 16 -q "$GW" >/dev/null 2>&1 &
        ping_pid=$!
    fi
    end=$((SECONDS + BLOCK))
    while [ "$SECONDS" -lt "$end" ] && kill -0 "$PID" 2>/dev/null; do sleep 1; done
    if [ -n "$ping_pid" ]; then kill "$ping_pid" 2>/dev/null; wait "$ping_pid" 2>/dev/null; ping_pid=""; fi
    on=$((1 - on))
done
