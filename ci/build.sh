#!/bin/bash
# Build, test and package Dekkimon inside the SteamOS container (ci/steamos/Dockerfile).
#
#   docker run --rm -v "$PWD:/src" -w /src dekkimon-build ci/build.sh
#
# Needs the git submodules (see .github/workflows/release.yml). Output: dist/dekkimon-steamdeck.tar.gz and
# dist/SHA256SUMS. The tarball holds the binary, the libraries SteamOS lacks, the launcher,
# the installer, Steam artwork and the Steam Input layout.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${BUILD_DIR:-/tmp/dekkimon-build}"
VERSION="$(head -n1 "$SRC/dekkimon.version")"
git config --global --add safe.directory "$SRC" 2>/dev/null || true

cmake -S "$SRC" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCHIAKI_USE_SYSTEM_CURL=ON -DCHIAKI_ENABLE_TESTS=ON -DCHIAKI_ENABLE_STEAMDECK_NATIVE=ON \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build "$BUILD" -j "$(nproc)"
"$BUILD/test/chiaki-unit"
"$BUILD/test/chiaki-smoothbuffer"

PKG="$(mktemp -d)/dekkimon"
mkdir -p "$PKG/bin" "$PKG/lib" "$PKG/share"
install -m755 "$BUILD/gui/dekkimon" "$PKG/bin/dekkimon"
strip "$PKG/bin/dekkimon"
# Libraries the Steam Deck doesn't ship. Everything else comes from SteamOS itself.
cp -L "$(find "$BUILD" -name 'libcpp-steam-tools.so' | head -1)" "$PKG/lib/"
cp -L /usr/lib/libminiupnpc.so.21 "$PKG/lib/"
# FFmpeg 8 (linked from the SteamOS mirror) isn't on a stock Deck, nor are two of its
# dependencies. List found by adding missing libraries on a real Deck until ldd was clean.
for lib in libavcodec.so.62 libavformat.so.62 libavutil.so.60 libswresample.so.6 \
           libbluray.so.3 libx265.so.216; do
    cp -L "/usr/lib/$lib" "$PKG/lib/"
done
install -m755 "$SRC/scripts/deck/dekkimon.sh" "$PKG/dekkimon.sh"
install -m755 "$SRC/installer/dekkimon-install.sh" "$PKG/dekkimon-install.sh"
cp -r "$SRC/installer/steam" "$PKG/share/steam"
install -m644 "$SRC/gui/res/dekkimon-icon.png" "$PKG/share/dekkimon-icon.png"
install -m644 "$SRC/COPYING" "$PKG/COPYING"
install -m644 "$SRC/installer/README.txt" "$PKG/README.txt"
echo "$VERSION" > "$PKG/VERSION"

# Fail if the binary needs a library that is neither bundled nor part of SteamOS's packages.
missing=$(LD_LIBRARY_PATH="$PKG/lib" ldd "$PKG/bin/dekkimon" | grep 'not found' || true)
[ -z "$missing" ] || { echo "missing libraries:"; echo "$missing"; exit 1; }

mkdir -p "$SRC/dist"
TAR="dekkimon-steamdeck.tar.gz"
tar -C "$(dirname "$PKG")" --owner=0 --group=0 -czf "$SRC/dist/$TAR" dekkimon
cp "$SRC/installer/dekkimon-install.sh" "$SRC/installer/Install Dekkimon.desktop" "$SRC/dist/"
(cd "$SRC/dist" && sha256sum "$TAR" dekkimon-install.sh > SHA256SUMS)
ls -la "$SRC/dist"
