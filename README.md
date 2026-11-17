# Dekkimon <sub>デッキ門</sub>

**PlayStation Remote Play for the Steam Deck**, with a console-style interface built for the
Deck's screen and controls.

*Dekkimon* means "Deck Gate" in Japanese: a gate from your Deck to your PlayStation.

## Features

- **Made for the Steam Deck.** Large, controller-first menus at 1280×800, an animated home
  screen, and the PS button on L4.
- **Sign in to PSN with your phone.** Scan a QR code on the Deck and sign in on your phone.
  You don't need to type anything on the Deck.
- **Smooth streaming over Wi-Fi.** Includes fixes for video freezes after packet loss,
  larger network buffers, and a built-in Wi-Fi signal indicator.
- **Automatic HDR.** HDR is used when your screen supports it (Steam Deck OLED or an HDR TV).
  Otherwise Dekkimon falls back to SDR so colors don't look washed out.
- **One-step install.** The installer adds Dekkimon to your Steam library with artwork and a
  ready-made controller layout.
- PS5 and PS4, at home or remotely over the internet.

## Install

On your Steam Deck, in **Desktop Mode**:

1. Download [**Install Dekkimon.desktop**](https://github.com/GabrieleLozupone/dekkimon/releases/latest/download/Install%20Dekkimon.desktop).
2. Double-click it in your Downloads folder, and choose **Continue** if you're asked.
3. Return to Gaming Mode. Dekkimon is in **Library › Non-Steam**.

Or paste this into Konsole:

```sh
curl -fsSL https://github.com/GabrieleLozupone/dekkimon/releases/latest/download/dekkimon-install.sh | bash
```

To update, run the installer again. Your consoles and settings are kept.
[More in the install guide](docs/install.md), including how to uninstall.

## Guides

- [Install, update and uninstall](docs/install.md)
- [First connection, pairing and PSN sign-in](docs/first-connection.md)
- [Controls](docs/controls.md)
- [Settings explained](docs/settings.md)
- [Smooth streaming over Wi-Fi](docs/network-optimization.md) (router settings, bitrate, HDR,
  troubleshooting)

## For developers

- [Building and testing](docs/building.md)
- [Taking changes from chiaki-ng](docs/upstream.md)

## Credits and license

Dekkimon is based on [chiaki-ng](https://github.com/chiaki-ng/chiaki-ng) by Street Pea, a fork
of [Chiaki](https://git.sr.ht/~thestr4ng3r/chiaki) by Florian Markl. Thanks to everyone who
worked on them. The PlayStation Remote Play protocol code is theirs.

Dekkimon is free software under the [GNU Affero General Public License version 3](COPYING)
(with the OpenSSL exception in [LICENSES/](LICENSES)), without any warranty.

Dekkimon is not affiliated with, endorsed by or certified by Sony Interactive Entertainment or
Valve. PlayStation, PS5, PS4 and DualSense are trademarks of Sony Interactive Entertainment.
Steam and Steam Deck are trademarks of Valve Corporation.
