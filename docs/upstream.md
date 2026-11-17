# Taking changes from chiaki-ng

Dekkimon is an independent repository, not a GitHub fork, but it keeps chiaki-ng's full
history. So you can merge new chiaki-ng releases with normal `git merge`. The chiaki-ng
repository is the `upstream` remote, and pushing to it is disabled.

## Merge chiaki-ng

```sh
scripts/dev/merge-upstream.sh              # latest chiaki-ng main
scripts/dev/merge-upstream.sh v1.11.0      # a specific chiaki-ng tag
```

The script never pushes and never changes `main`. It does the following:

1. Adds the `upstream` remote if it's missing and disables pushing to it.
2. Fetches chiaki-ng and lists the commits it is about to merge.
3. Creates a branch `upstream-merge-<date>` from `main` and merges into it.
4. Drops upstream changes to the paths Dekkimon removed on purpose: Android, Switch,
   Windows, macOS, Flatpak and AppImage packaging, their CI, and the chiaki4deck docs site.
   [`scripts/dev/upstream-removed.txt`](../scripts/dev/upstream-removed.txt) lists them. A
   file that still exists in `main` is never dropped.
5. If nothing conflicts, it commits the merge. Otherwise it lists the conflicting files.

Then:

1. Resolve the conflicts (`git status`), then `git add` and `git commit`.
2. Build and test (see [building.md](building.md)): unit tests, the GUI smoke tests, and
   GPU previews for anything that changes the UI.
3. Merge the branch into `main` and push it. CI builds it again.

To give up a merge, run `git merge --abort`, switch back to `main`, and delete the branch.

## Keep merges small

Most of Dekkimon lives in its own files, so upstream changes rarely touch the same lines.

| Area | Where Dekkimon's changes live |
| --- | --- |
| Portal UI | New QML files `gui/src/qml/Portal*.qml`, `controls/`, `shaders/`, and dialogs that were rewritten |
| Phone sign-in, Wi-Fi indicator, QR codes | New files `gui/src/psnphonelogin.cpp`, `wifimonitor.cpp`, `qrimageprovider.cpp`, `third-party/qrcodegen/` |
| App name and version | `gui/CMakeLists.txt` (`OUTPUT_NAME dekkimon`), `gui/src/main.cpp`, `dekkimon.version` |
| Steam Deck launcher, installer, CI | `scripts/deck/`, `installer/`, `ci/`, `.github/workflows/dekkimon.yml` |
| Streaming fixes | Small, commented changes in `lib/` and `gui/src/streamsession.cpp`, `qmlmainwindow.cpp` |

Rules for new work:

- **Keep internal names.** `libchiaki`, `chiaki_*`, the `chiaki` CMake target, the
  `org.streetpea.chiaking` QML module and the `Chiaki/Chiaki.conf` settings file stay as they
  are. Only names that users see are Dekkimon.
- **Put new features in new files** and connect them with a few lines in the existing code.
- **Leave platform code alone.** Upstream's `#ifdef` code for Windows, macOS, Android and the
  Switch is never compiled for the Deck. Deleting it would only create conflicts.
- **Mark changes to upstream files** with a short comment that starts with `Dekkimon:` when
  the reason isn't obvious from the code.

## Things to check after a merge

- `CMakeLists.txt`: upstream may add options for removed platforms again. They're harmless,
  but remove any `add_subdirectory(android|switch)`.
- `gui/CMakeLists.txt`: new source files must still be listed, and `OUTPUT_NAME dekkimon` must
  stay.
- New user-visible strings that say "chiaki-ng" should say "Dekkimon" (`git grep -n chiaki-ng
  -- gui/src`). Credits in About stay.
- New dependencies: if the binary needs a library that SteamOS doesn't ship, CI fails at the
  `ldd` check in `ci/build.sh`. Bundle it there, next to libcpp-steam-tools and libminiupnpc.
