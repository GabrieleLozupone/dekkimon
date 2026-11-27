# Changelog

## 0.2.0

**Streaming**
- Smooth buffer: when Wi-Fi holds the video back for a moment (100–150 ms is common) and then
  delivers it all at once, Dekkimon now keeps a small reserve of frames and plays them at an
  even pace instead of freezing and jumping. The first hold of a bad stretch is still visible;
  the ones after it are hidden. The reserve is zero on a clean network, grows only after a real
  network stall (not when a game drops below 60 fps), and goes back to zero about 15 seconds
  after the network calms down. At most 150 ms; see
  [Smooth streaming › Smooth buffer](https://github.com/GabrieleLozupone/dekkimon/blob/main/docs/network-optimization.md#9-smooth-buffer).

**Interface**
- Remote Play over the internet (through PSN) now uses the same connection screen as at home:
  the globe, the console's name and the current step, instead of a plain spinner.

## 0.1.0

First public release of Dekkimon, based on chiaki-ng 1.10.1.

**New interface**
- Console-style home screen with an animated globe, a consoles screen, and a quick menu.
- New in-stream menu with a connection page (Wi-Fi signal, bitrate, packet loss) and a
  Picture & HDR page.
- Every settings page and dialog was redone for the controller, at the Deck's 1280×800.
- Sign in to PlayStation Network with your phone: scan a QR code on the Deck and sign in on
  the phone.

**Streaming**
- Video no longer stays frozen after a lost frame. A watchdog asks the console for a new key
  frame when the decoder stops producing pictures.
- Larger network receive buffer, so Wi-Fi bursts don't overflow the socket.
- Automatic HDR: HDR only when the screen supports it, otherwise correct SDR colors.

**Steam Deck**
- One-step installer: Steam shortcut, artwork and the recommended Steam Input layout
  (L4 = PS button, R4 = menu, left trackpad click = touchpad).
- Settings are imported once from the pre-release "Chiaki Portal" build.

**Removed**
- Windows, macOS, Android, Nintendo Switch, Flatpak and AppImage builds. Dekkimon is for the
  Steam Deck only.
