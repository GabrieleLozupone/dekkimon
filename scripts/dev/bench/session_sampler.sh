#!/bin/bash
# Per-second system sampler for Dekkimon sessions on Steam Deck.
#   session_sampler.sh <chiaki-pid> <out.csv>
# Runs until the chiaki process exits. Reads only kernel/sysfs counters (no root, no config,
# no credentials). Correlate with bench/<stamp>.csv by wall_time (scripts/dev/bench/bench_report.py).
#
# Columns
#   wifi_*            iw station dump of the associated AP (signal, MCS/width, retries, failures,
#                     rx drops, beacon loss) + frequency, so channel switches (DFS) and roams show.
#   udp_rcvbuf_errs   system-wide UDP datagrams dropped because a socket buffer was full.
#   chiaki_udp_drops  the same, but only for chiaki's own sockets (/proc/net/udp "drops").
#   cpu_mhz/gpu_mhz   average CPU frequency, current GPU sclk.
#   apu_c/wifi_c      APU (k10temp) and Wi-Fi chip (ath11k) temperature.
#   apu_w/batt_w      APU package power (amdgpu power1_average) and battery discharge power.
#   chiaki_cpu_ticks  utime+stime of the chiaki process (100 ticks = 1 CPU second).
#   keepalive         state of keepalive_ab.sh (1 = gateway pings running, 0 = off, empty = not running).
set -u
PID="$1"; OUT="$2"
KA_STATE="${OUT%.sys.csv}.ka"
IF="$(iw dev 2>/dev/null | awk '/Interface/{print $2; exit}')"

hwmon() { for h in /sys/class/hwmon/hwmon*; do [ "$(cat "$h/name" 2>/dev/null)" = "$1" ] && { echo "$h"; return; }; done; }
K10="$(hwmon k10temp)"; ATH="$(hwmon ath11k_hwmon)"; GPU="$(hwmon amdgpu)"; BAT="$(hwmon BAT1)"

rd() { cat "$1" 2>/dev/null || echo ""; }

echo "wall_time,wifi_freq,wifi_signal,wifi_signal_avg,wifi_rx_rate,wifi_tx_rate,wifi_tx_retries,wifi_tx_failed,wifi_rx_drop_misc,wifi_beacon_loss,udp_rcvbuf_errs,chiaki_udp_drops,cpu_mhz,gpu_mhz,apu_c,wifi_c,apu_w,batt_w,chiaki_cpu_ticks,keepalive" >"$OUT"

while kill -0 "$PID" 2>/dev/null; do
    t0="$(date +%s%N)"
    now="$(date +%Y-%m-%dT%H:%M:%S.%3N)"
    link="$(iw dev "$IF" link 2>/dev/null)"
    st="$(iw dev "$IF" station dump 2>/dev/null)"
    freq="$(awk '/freq:/{print $2; exit}' <<<"$link")"
    sig="$(awk -F'\t' '/^\tsignal:/{split($3,a," "); print a[1]; exit}' <<<"$st")"
    sigavg="$(awk -F'\t' '/signal avg:/{split($3,a," "); print a[1]; exit}' <<<"$st")"
    rxr="$(awk -F'\t' '/rx bitrate:/{print $3; exit}' <<<"$st" | sed 's/ MBit\/s.*HE-MCS \([0-9]*\).*/ mcs\1/; s/,//g')"
    txr="$(awk -F'\t' '/tx bitrate:/{print $3; exit}' <<<"$st" | sed 's/ MBit\/s.*HE-MCS \([0-9]*\).*/ mcs\1/; s/,//g')"
    retr="$(awk -F'\t' '/tx retries:/{print $3; exit}' <<<"$st")"
    fail="$(awk -F'\t' '/tx failed:/{print $3; exit}' <<<"$st")"
    rxd="$(awk -F'\t' '/rx drop misc:/{print $3; exit}' <<<"$st")"
    bl="$(awk -F'\t' '/beacon loss:/{print $3; exit}' <<<"$st")"
    rcvbuf="$(awk '/^Udp:/{n++} /^Udp:/ && n==2 {print $6}' /proc/net/snmp)"
    # chiaki's sockets: inode list from its fds, drops = column 13 of /proc/net/udp(6)
    inodes="$(ls -l /proc/"$PID"/fd 2>/dev/null | grep -o 'socket:\[[0-9]*\]' | tr -dc '0-9\n')"
    cdrops=0
    if [ -n "$inodes" ]; then
        cdrops="$(awk 'NR==FNR{ino[$1]=1; next} FNR>1 && ($10 in ino){s+=$13} END{print s+0}' <(echo "$inodes") /proc/net/udp /proc/net/udp6 2>/dev/null)"
    fi
    cpu="$(awk '{s+=$1; n++} END{if(n) printf "%d", s/n/1000}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null)"
    gpu="$(awk '{printf "%d", $1/1000000}' "$GPU/freq1_input" 2>/dev/null)"
    apuc="$(awk '{printf "%.1f", $1/1000}' "$K10/temp1_input" 2>/dev/null)"
    wific="$(awk '{printf "%.1f", $1/1000}' "$ATH/temp1_input" 2>/dev/null)"
    apuw="$(awk '{printf "%.2f", $1/1000000}' "$GPU/power1_average" 2>/dev/null)"
    # battery: in0 (uV) * curr1 (uA); negative current = discharging
    battw="$(awk -v v="$(rd "$BAT/in0_input")" -v c="$(rd "$BAT/curr1_input")" 'BEGIN{if(v!=""&&c!="") printf "%.2f", v*c/1e12}')"
    ticks="$(awk '{print $14+$15}' /proc/"$PID"/stat 2>/dev/null)"
    ka="$(cat "$KA_STATE" 2>/dev/null)"
    echo "$now,$freq,$sig,$sigavg,$rxr,$txr,$retr,$fail,$rxd,$bl,$rcvbuf,$cdrops,$cpu,$gpu,$apuc,$wific,$apuw,$battw,$ticks,$ka" >>"$OUT"
    # one row per second: sleep only for what is left of the second
    left_ms=$(( 1000 - ($(date +%s%N) - t0) / 1000000 ))
    [ "$left_ms" -gt 0 ] && sleep "$(awk -v m="$left_ms" 'BEGIN{printf "%.3f", m/1000}')"
done
