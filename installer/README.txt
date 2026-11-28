Dekkimon (デッキ門) - PlayStation Remote Play for the Steam Deck
https://github.com/GabrieleLozupone/dekkimon

Install or update (Desktop Mode, in this folder):
    bash dekkimon-install.sh

Uninstall:
    bash ~/Applications/dekkimon/dekkimon-install.sh --uninstall

The installer puts the app in ~/Applications/dekkimon and adds "Dekkimon" to your
Steam library with artwork and the recommended controller layout. Guides:
https://github.com/GabrieleLozupone/dekkimon/tree/main/docs

Contents:
    bin/dekkimon            the app
    lib/                    the libraries SteamOS doesn't include
                            (FFmpeg, libcpp-steam-tools, libminiupnpc)
    dekkimon.sh             launcher (Steam starts this)
    dekkimon-install.sh     installer, updater and uninstaller
    share/                  icon, Steam artwork and Steam Input layout

Dekkimon is based on chiaki-ng by Street Pea, a fork of Chiaki by Florian Markl.
Free software under the GNU Affero General Public License version 3 (see COPYING),
without any warranty. Not affiliated with Sony Interactive Entertainment or Valve.
PlayStation, PS5 and Steam Deck are trademarks of their respective owners.
