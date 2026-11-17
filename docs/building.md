# Building Dekkimon

Dekkimon is built in a container that matches SteamOS 3.9. It uses the same packages, and
the same Qt version, as the Steam Deck. So the binary runs on the Deck with only two extra
libraries (libcpp-steam-tools and libminiupnpc), which the release package includes.

## Requirements

- Docker. On Windows, Docker in WSL 2 works.
- Git, with the submodules Dekkimon uses:

  ```sh
  git submodule update --init --depth 1 test/munit third-party/nanopb third-party/gf-complete \
      third-party/jerasure third-party/cpp-steam-tools
  ```

## Build the release package

```sh
docker build -t dekkimon-build ci/steamos
docker run --rm -v "$PWD:/src" -w /src dekkimon-build bash ci/build.sh
```

This builds Dekkimon, runs the unit tests and writes these files to `dist/`:

| File | What it is |
| --- | --- |
| `dekkimon-steamdeck.tar.gz` | The app, its launcher, the two bundled libraries, Steam artwork and the Steam Input layout |
| `dekkimon-install.sh` | The installer, which downloads the package itself |
| `Install Dekkimon.desktop` | Double-click installer for Desktop Mode |
| `SHA256SUMS` | Checksums the installer verifies |

The container image has a pinned SteamOS keyring and downloads packages from Valve's SteamOS
mirror. The first build of the image takes a few minutes.

## Tests

```sh
# Unit tests run inside ci/build.sh. Installer test (fake home folder, no Steam needed):
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/src" -w /src dekkimon-build python3 test/installer/test_installer.py dist/dekkimon-steamdeck.tar.gz

# GUI smoke tests (any OS, software renderer, mock backend):
uv run --with PySide6 python test/gui/mainview_smoke.py
uv run --with PySide6 python test/gui/portal_smoke.py
uv run --with PySide6 python test/gui/settings_smoke.py
```

## GPU previews

Before you change the UI, render it with the real GPU renderer and a mock backend. The
animated globe needs the GPU because it is a shader.

```sh
uv run --with PySide6 --with pillow --with segno python test/gui/portal_preview.py home consoles settings
```

The pictures are written to `<temp>/chiaki-portal-preview/`. Run the script without
arguments for the default scenes, or see the `scene ==` branches in the script for all of
them (`legacy`, `menus`, `psn-phone`, ...). The `connect` scene also records the connect
animation as frames and an MP4.

## Try a build on the Deck

Install your own package with the normal installer. It keeps your settings:

```sh
scp dist/dekkimon-steamdeck.tar.gz dist/dekkimon-install.sh deck@<deck-ip>:/tmp/
ssh deck@<deck-ip> bash /tmp/dekkimon-install.sh --tarball /tmp/dekkimon-steamdeck.tar.gz
```

The installer closes Steam while it updates the shortcut, so don't run it while you're
playing. If you only replace `bin/dekkimon` and Steam stays untouched, use
`--no-steam`.

## Releases

1. Update `dekkimon.version` and add a section for it to `CHANGELOG.md`.
2. Commit, then tag and push: `git tag v0.1.0 && git push origin main v0.1.0`.
3. GitHub Actions builds, tests and publishes the release with the files above. The
   installer always downloads the latest release.
