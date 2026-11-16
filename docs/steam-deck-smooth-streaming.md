# Smooth Remote Play on Steam Deck

Most stutter, freezes and blurry motion when streaming from a PS5 to a Steam Deck are caused by
the Wi-Fi link, not by the app. This guide lists what to check, in order of impact. Each step
says why it matters and how to undo it.

Everything here was measured on a Steam Deck OLED (SteamOS 3.9) streaming 1080p60 HDR over
5 GHz Wi-Fi; the numbers are from those sessions.

## Quick checklist

| Step | Where | Fixes |
| --- | --- | --- |
| 1. 5 GHz, fixed channel 36–48, 80 MHz wide | Router | Narrow link, uneven frame delivery at higher bitrates |
| 2. Band steering off | Router | Short disconnects when the signal is weak |
| 3. Stop background Wi-Fi scans | Steam Deck | A stutter every ~35 seconds |
| 4. Refresh rate 60 Hz | Steam Deck | Judder in fast camera moves (OLED runs at 90 Hz) |
| 5. Bitrate that fits your link | App | Stutter at high bitrate, blur at low bitrate |
| 6. "Request a key frame after errors" off | App | Half-second freezes after a lost packet |
| 7. Motion blur and film grain off | Game | Soft image while moving fast |
| 8. HDR on in Steam, calibrate on the Deck | Steam / PS5 | Wrong brightness or washed-out HDR |

## 1. Router: 5 GHz on channel 36–48 at 80 MHz

**Why.** The Deck always uses whatever channel width the router chooses. On a 40 MHz channel
the Deck received at 69–103 Mbit/s; on 80 MHz the same Deck, same router, got 288 Mbit/s. A
stream at 20–25 Mbps fills a narrow link enough that frames arrive late and in clumps, which
looks like stutter even though no data is lost.

**Why the channel matters, not just the width setting.** Channels 52–144 are radar (DFS)
channels. Routers often stay at 40 MHz there or drop to it after a radar check, even when
"20/40/80" is selected. Channels 36, 40, 44 and 48 are not radar channels and form one 80 MHz
block, so the router has no reason to narrow. Which one of the four you pick only sets the
"primary" slice; the 80 MHz block is the same. Use 36 unless a neighbour's network sits on it.

**What to set** (names vary by router; TIM routers call them *Canale* and *Larghezza di banda*):

1. Open the router page (often http://192.168.1.1; the password is on the router label).
2. 5 GHz Wi-Fi settings:
   - **Channel:** 36 (or 40/44/48), not Automatic.
   - **Automatic channel selection / Wi-Fi optimisation:** off, so the router does not move back.
   - **Bandwidth:** 20/40/80. If the router still uses 40 MHz, try 20/40/80/160 once: on some
     routers this is what unlocks the wider modes. If you ever see stutter return with 160
     selected, go back to 20/40/80 (160 MHz needs radar channels again).
   - **Wi-Fi standard:** ax (Wi-Fi 6) or be (Wi-Fi 7); an "a/n" mode is limited to 40 MHz.
3. Save, wait for Wi-Fi to come back, then turn the Deck's Wi-Fi off and on. The channel width
   is agreed when the Deck connects, so the Deck keeps the old width until it reconnects.

**Check on the Deck** (Desktop Mode → Konsole):

```bash
iw dev wlan0 link | grep -E "signal|bitrate"
iw dev wlan0 info | grep channel
```

You want `width: 80 MHz` and an rx bitrate that mentions `80MHz`.

**Signal strength** (the `signal:` line): better than -70 dBm is good, -70 to -80 dBm works
with a moderate bitrate, worse than -80 dBm will struggle at any setting. A wider channel
spreads the router's power, so check the signal from where you actually play.

## 2. Router: band steering off

Band steering moves devices between 2.4 GHz and 5 GHz on its own. When the Deck's 5 GHz
signal gets weak, the router may try to push it to 2.4 GHz, sometimes by disconnecting it
briefly. During a stream that is a freeze. Turning it off keeps the Deck on 5 GHz.

Trade-off: your other devices stay on whichever band they joined instead of being moved
automatically. If a device far from the router misbehaves afterwards, turn it back on.

## 3. Steam Deck: stop background Wi-Fi scans

**Symptom.** A burst of stutter or freezing every ~35 seconds that lasts 3–5 seconds, often
worse when the signal is weaker.

**Cause.** When the signal is weaker than -70 dBm, SteamOS (NetworkManager) scans for other
access points every 30 seconds so it could roam. A scan takes about 5 seconds, and during it
the Wi-Fi radio keeps leaving your channel to listen on others. Video arrives in ~180 ms gaps
and some packets are lost. Above -70 dBm it scans only about once a day, which is why the
problem comes and goes.

**Fix.** Lock the Deck's Wi-Fi profile to your router's access point. A locked profile has
nothing to roam to, so NetworkManager stops scanning. In Desktop Mode → Konsole (asks for your
Deck password):

```bash
nmcli -t -f NAME,UUID,DEVICE connection show --active    # note the UUID of the wlan0 line
BSSID=$(iw dev wlan0 link | awk '/^Connected to/{print toupper($3)}'); echo "$BSSID"
sudo nmcli connection modify <UUID> 802-11-wireless.bssid "$BSSID"
sudo nmcli connection up <UUID>
```

If `echo` prints nothing, the Deck is not connected; stop there.

**Check that it worked.** `timeout 75 iw event -t` should print no `scan started` lines
(before the fix: two in 75 seconds).

**Trade-off.** The Deck only uses that one access point. If you add a mesh node or extender,
or replace the router, the Deck will not roam to or join the new one until you undo it.
Changing the router's channel does not affect the lock. Opening the Wi-Fi list in Steam's
settings still scans, so avoid that mid-stream.

**Undo:**

```bash
sudo nmcli connection modify <UUID> 802-11-wireless.bssid ""
sudo nmcli connection up <UUID>
```

## 4. Steam Deck: refresh rate 60 Hz

The Steam Deck OLED screen runs at 90 Hz. A 60 fps stream does not divide evenly into 90 Hz,
so frames alternate between being shown for one and two refreshes. That judder is most visible
in fast pans. While streaming: Quick Access (`…`) → Performance → enable per-game settings →
**Refresh Rate 60 Hz**. It costs nothing and does not affect the network.

## 5. App: a bitrate that fits your link

The bitrate setting is a maximum; the console picks its actual target below it and lowers it
when packets are lost. It does not react to frames arriving late, so a bitrate too high for
your link causes stutter without the console noticing.

| Your link | Suggested bitrate (1080p60) |
| --- | --- |
| 40 MHz channel or signal worse than -75 dBm | 18 Mbps |
| 80 MHz channel, signal -70 to -75 dBm | 20 Mbps |
| 80 MHz channel, signal better than -70 dBm | 25 Mbps, then try higher |

Measured: at 25 Mbps on a 40 MHz link the stream had ~125 ms delivery gaps with no packet loss;
at 18 Mbps the same link was clean. Higher bitrate gives a sharper image in fast motion only if
the link has room for it.

Keep **1080p, 60 fps and HEVC (H.265)**. 1080p is downscaled to the Deck's screen, which is
sharper than 720p upscaled. Changing the resolution resets the bitrate to automatic, so set the
bitrate again afterwards.

## 6. App: "Request a key frame after errors" off

When a frame cannot be repaired after packet loss, this option makes the app wait for a fresh
key frame before showing anything, which is a freeze of 0.4–1.6 seconds. With it off, the app
keeps going and the console repairs the picture within a moment; you may see a brief glitch
instead. On Wi-Fi, a short glitch is less disruptive than a freeze.

## 7. Game: motion blur and film grain off

Antialiasing, motion blur and resolution scaling happen inside the game on the console; the
Deck receives finished video. In fast games (swinging, driving), turn off **motion blur**,
**film grain** and **depth of field** in the game's own settings. Motion blur is the main
reason fast motion looks soft. Film grain is random noise the video encoder wastes bitrate on,
so turning it off leaves more bitrate for real detail.

## 8. HDR

- Enable HDR in Steam → Settings → Display (and for this shortcut if asked). If it is off, the
  app tone-maps the console's HDR down to SDR.
- Run the console's **Adjust HDR** calibration while streaming on the Deck, so it matches the
  Deck's screen rather than your TV. The Deck OLED peaks around 1000 nits, which the app
  targets by default.

## Steam Input: renaming the shortcut

Steam stores controller layouts for non-Steam games by the game's **name**. If you rename the
app's shortcut, Steam starts the new name with its default layout, and custom bindings (back
grips, trackpad clicks) appear to stop working. Either set the layout up again for the new
name, or copy the old layout folder in
`~/.local/share/Steam/steamapps/common/Steam Controller Configs/<user id>/config/<old name>/`
to a folder with the new name in lower case, and restart Steam.

## Troubleshooting

| What you see | Most likely cause | Step |
| --- | --- | --- |
| Stutter every ~35 s, lasting a few seconds | Background Wi-Fi scans | 3 |
| Steady micro-stutter at higher bitrate, no artifacts | Link too narrow for the bitrate | 1, 5 |
| Half-second freezes after a glitch | Key frame after errors is on | 6 |
| Short drop-outs when far from the router | Band steering or weak signal | 2, 1 |
| Judder in camera pans, otherwise smooth | 90 Hz screen with a 60 fps stream | 4 |
| Soft, smeared image while moving fast | Motion blur in game, or bitrate too low | 7, 5 |
| Image soft only after losses | Console lowered its bitrate after packet loss | 1, 3 |
