#!/bin/bash
# Dekkimon installer for the Steam Deck (run it in Desktop Mode).
#
#   Install or update:   bash dekkimon-install.sh
#   Uninstall:           bash dekkimon-install.sh --uninstall          (keeps your settings)
#                        bash dekkimon-install.sh --uninstall --purge  (removes everything)
#
# Other options:
#   --version X.Y.Z      install that release instead of the latest one
#   --tarball FILE       install from a downloaded dekkimon-steamdeck.tar.gz
#   --no-steam           don't touch Steam (no shortcut, artwork or controller layout)
#   --reset-controls     replace the Dekkimon Steam Input layout with the recommended one
#   --reset-artwork      replace the Dekkimon artwork in your Steam library
#   --yes                don't ask before closing Steam
#
# What it does: installs the app in ~/Applications/dekkimon, adds "Dekkimon" to Steam as a
# non-Steam game with artwork and the recommended Steam Input layout (L4 = PS button,
# R4 = menu, left trackpad click = touchpad), and adds Dekkimon to the Desktop Mode menu.
# Steam is closed while its shortcut list is edited and started again afterwards.
# Nothing needs root, and nothing outside your home folder is changed.
set -euo pipefail

REPO="GabrieleLozupone/dekkimon"
APP_NAME="Dekkimon"
APP_ID_NAME="dekkimon"   # Steam Input keys layouts by the shortcut's name, in lower case
DEST="$HOME/Applications/dekkimon"
DESKTOP_FILE="$HOME/.local/share/applications/dekkimon.desktop"
ASSET="dekkimon-steamdeck.tar.gz"

MODE=install VERSION="" TARBALL="" STEAM=1 RESET_CONTROLS=0 RESET_ARTWORK=0 PURGE=0 YES=0
while [ $# -gt 0 ]; do
    case "$1" in
        --uninstall) MODE=uninstall ;;
        --purge) PURGE=1 ;;
        --version) VERSION="${2:?--version needs a value}"; shift ;;
        --tarball) TARBALL="${2:?--tarball needs a file}"; shift ;;
        --no-steam) STEAM=0 ;;
        --reset-controls) RESET_CONTROLS=1 ;;
        --reset-artwork) RESET_ARTWORK=1 ;;
        --yes|-y) YES=1 ;;
        -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
    esac
    shift
done

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }
ask() {  # ask "question" -> 0 for yes
    [ "$YES" = 1 ] && return 0
    local reply
    if [ -r /dev/tty ]; then
        read -r -p "$1 [Y/n] " reply </dev/tty || reply=n
    else
        die "$1 Run again with --yes to confirm."
    fi
    case "$reply" in ""|y|Y|yes|Yes) return 0 ;; *) return 1 ;; esac
}

[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || die "Dekkimon runs on the Steam Deck (x86_64 Linux) only."
[ "$(id -u)" != 0 ] || die "Don't run the installer with sudo; it installs into your home folder."
command -v python3 >/dev/null || die "python3 is missing (it is part of SteamOS)."

STEAM_ROOT=""
for d in "$HOME/.local/share/Steam" "$HOME/.steam/steam"; do
    [ -d "$d/userdata" ] && { STEAM_ROOT="$(readlink -f "$d")"; break; }
done

app_running() { pgrep -f "$DEST/bin/dekkimon" >/dev/null 2>&1; }
steam_running() { pgrep -x steam >/dev/null 2>&1; }

STEAM_WAS_RUNNING=0
close_steam() {
    steam_running || return 0
    STEAM_WAS_RUNNING=1
    say "Steam has to be closed while Dekkimon is added to your library (it rewrites the list on exit)."
    ask "Close Steam now? It will be started again when the installer is done." || die "Steam is still running; nothing was changed in Steam."
    steam -shutdown >/dev/null 2>&1 || true
    for _ in $(seq 1 120); do steam_running || return 0; sleep 0.5; done
    die "Steam did not close within a minute. Close it from its menu and run the installer again."
}
start_steam() {
    [ "$STEAM_WAS_RUNNING" = 1 ] || return 0
    steam_running && return 0
    say "Starting Steam again"
    (setsid steam >/dev/null 2>&1 </dev/null &) || warn "Could not start Steam; start it yourself."
}

# Steam helper: shortcut, artwork and Steam Input layout. Python is used for Steam's binary
# shortcuts.vdf format. Arguments: action steam_root dest app_name layout_name share_dir flags
steam_tool() {
    python3 - "$@" <<'PYEOF'
import os, re, shutil, struct, sys, time, zlib

action, steam_root, dest, app_name, layout_name, share = sys.argv[1:7]
flags = set(sys.argv[7:])
launcher = os.path.join(dest, "dekkimon.sh")
icon = os.path.join(dest, "share", "dekkimon-icon.png")
legacy_dirs = ("/Applications/dekkimon/", "/Applications/chiaki-portal/")

# --- binary VDF (shortcuts.vdf) ----------------------------------------------------------
def read_cstr(b, i):
    j = b.index(b"\x00", i)
    return b[i:j].decode("utf-8", "surrogateescape"), j + 1

def parse(b, i=0):
    items = []
    while True:
        t = b[i]; i += 1
        if t == 0x08:
            return items, i
        key, i = read_cstr(b, i)
        if t == 0x00:
            val, i = parse(b, i)
        elif t == 0x01:
            val, i = read_cstr(b, i)
        elif t == 0x02:
            val = struct.unpack_from("<i", b, i)[0]; i += 4
        elif t == 0x03:
            val = struct.unpack_from("<f", b, i)[0]; i += 4
        elif t == 0x07:
            val = struct.unpack_from("<Q", b, i)[0]; i += 8
        elif t == 0x0a:
            val = struct.unpack_from("<q", b, i)[0]; i += 8
        else:
            raise ValueError("unknown VDF type 0x%02x at %d" % (t, i - 1))
        items.append([t, key, val])

def dump(items):
    out = bytearray()
    for t, key, val in items:
        out.append(t); out += key.encode("utf-8", "surrogateescape") + b"\x00"
        if t == 0x00: out += dump(val)
        elif t == 0x01: out += val.encode("utf-8", "surrogateescape") + b"\x00"
        elif t == 0x02: out += struct.pack("<i", val)
        elif t == 0x03: out += struct.pack("<f", val)
        elif t == 0x07: out += struct.pack("<Q", val)
        elif t == 0x0a: out += struct.pack("<q", val)
    out.append(0x08)
    return bytes(out)

def get(entry, key, default=None):
    for t, k, v in entry:
        if k.lower() == key.lower():
            return v
    return default

def put(entry, key, t, val):
    for item in entry:
        if item[1].lower() == key.lower():
            item[0], item[2] = t, val
            return
    entry.append([t, key, val])

# --- account ------------------------------------------------------------------------------
def account_ids():
    users = os.path.join(steam_root, "userdata")
    ids = [d for d in os.listdir(users) if d.isdigit() and d != "0"]
    try:
        text = open(os.path.join(steam_root, "config", "loginusers.vdf"), encoding="utf-8", errors="replace").read()
        for sid, body in re.findall(r'"(\d{17})"\s*\{([^}]*)\}', text):
            if re.search(r'"MostRecent"\s*"1"', body):
                acc = str(int(sid) - 76561197960265728)
                if acc in ids:
                    return [acc]
    except OSError:
        pass
    ids.sort(key=lambda d: os.path.getmtime(os.path.join(users, d)), reverse=True)
    return ids[:1]

def load_shortcuts(path):
    if not os.path.exists(path):
        return [[0x00, "shortcuts", []]]
    data = open(path, "rb").read()
    items, _ = parse(data)
    return items

def save_shortcuts(path, items):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        backup = path + ".before-dekkimon"
        if not os.path.exists(backup):
            shutil.copy2(path, backup)
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(dump(items))
    os.replace(tmp, path)

def is_ours(entry):
    exe = get(entry, "Exe", "") or ""
    return any(d in exe for d in legacy_dirs) or (get(entry, "AppName", "") or "").lower() == app_name.lower()

def unsigned(appid):
    return appid & 0xffffffff

def write_text_if(path, content, force):
    if force or not os.path.exists(path):
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)

def install_artwork(grid, appid, force):
    os.makedirs(grid, exist_ok=True)
    u = unsigned(appid)
    for src, name in (("portrait.png", "%dp.png" % u), ("wide.png", "%d.png" % u),
                      ("hero.png", "%d_hero.png" % u), ("logo.png", "%d_logo.png" % u)):
        dst = os.path.join(grid, name)
        if force or not os.path.exists(dst):
            shutil.copyfile(os.path.join(share, "steam", src), dst)
    write_text_if(os.path.join(grid, "%d.json" % u),
                  open(os.path.join(share, "steam", "logo.json"), encoding="utf-8").read(), force)

def configset_path(acc):
    return os.path.join(steam_root, "steamapps", "common", "Steam Controller Configs", acc, "config",
                        "configset_controller_neptune.vdf")

def install_layout(acc, force):
    cfg = os.path.dirname(configset_path(acc))
    layout_dir = os.path.join(cfg, layout_name)
    layout = os.path.join(layout_dir, "controller_neptune.vdf")
    if force or not os.path.exists(layout):
        os.makedirs(layout_dir, exist_ok=True)
        if os.path.exists(layout) and not os.path.exists(layout + ".before-dekkimon"):
            shutil.copy2(layout, layout + ".before-dekkimon")
        shutil.copyfile(os.path.join(share, "steam", "controller_neptune.vdf"), layout)
    cs = configset_path(acc)
    text = open(cs, encoding="utf-8").read() if os.path.exists(cs) else '"controller_config"\n{\n}\n'
    if not re.search(r'^\s*"%s"\s*$' % re.escape(layout_name), text, re.M | re.I):
        if os.path.exists(cs) and not os.path.exists(cs + ".before-dekkimon"):
            shutil.copy2(cs, cs + ".before-dekkimon")
        i = text.rstrip().rfind("}")
        entry = '\t"%s"\n\t{\n\t\t"autosave"\t\t"1"\n\t}\n' % layout_name
        text = text[:i] + entry + text[i:]
        with open(cs, "w", encoding="utf-8") as f:
            f.write(text)

def remove_layout(acc):
    cs = configset_path(acc)
    layout_dir = os.path.join(os.path.dirname(cs), layout_name)
    shutil.rmtree(layout_dir, ignore_errors=True)
    if os.path.exists(cs):
        text = open(cs, encoding="utf-8").read()
        text = re.sub(r'\n?[ \t]*"%s"\s*\{[^{}]*\}[ \t]*' % re.escape(layout_name), "", text, flags=re.I)
        with open(cs, "w", encoding="utf-8") as f:
            f.write(text)

accounts = account_ids()
if not accounts:
    sys.exit("No Steam account found. Start Steam and sign in once, then run the installer again.")

for acc in accounts:
    path = os.path.join(steam_root, "userdata", acc, "config", "shortcuts.vdf")
    grid = os.path.join(steam_root, "userdata", acc, "config", "grid")
    items = load_shortcuts(path)
    root = get(items, "shortcuts")
    if root is None:
        items = [[0x00, "shortcuts", []]]; root = items[0][2]
    ours = [e for e in root if e[0] == 0x00 and is_ours(e[2])]

    if action == "install":
        if ours:
            entry = ours[0][2]
            appid = get(entry, "appid")
            print("Updating the existing Steam shortcut (appid %d)" % unsigned(appid))
        else:
            entry = []
            u = zlib.crc32(('"%s"' % launcher + app_name).encode()) | 0x80000000
            appid = u - (1 << 32)
            for t, k, v in ((0x02, "appid", appid), (0x01, "AppName", app_name), (0x01, "Exe", ""),
                            (0x01, "StartDir", ""), (0x01, "icon", ""), (0x01, "ShortcutPath", ""),
                            (0x01, "LaunchOptions", ""), (0x02, "IsHidden", 0), (0x02, "AllowDesktopConfig", 1),
                            (0x02, "AllowOverlay", 1), (0x02, "OpenVR", 0), (0x02, "Devkit", 0),
                            (0x01, "DevkitGameID", ""), (0x02, "DevkitOverrideAppID", 0),
                            (0x02, "LastPlayTime", 0), (0x01, "FlatpakAppID", ""), (0x00, "tags", [])):
                entry.append([t, k, v])
            root.append([0x00, str(len(root)), entry])
            print("Adding Dekkimon to Steam (appid %d)" % unsigned(appid))
        put(entry, "AppName", 0x01, app_name)
        put(entry, "Exe", 0x01, '"%s"' % launcher)
        put(entry, "StartDir", 0x01, '"%s/"' % dest)
        put(entry, "icon", 0x01, icon)
        save_shortcuts(path, items)
        install_artwork(grid, appid, "reset-artwork" in flags)
        install_layout(acc, "reset-controls" in flags)
        print("Steam: shortcut, artwork and controller layout ready (account %s)" % acc)
        print("RUNGAMEID %d" % ((unsigned(appid) << 32) | 0x02000000))
    elif action == "uninstall":
        for item in ours:
            appid = get(item[2], "appid")
            root.remove(item)
            if appid is not None:
                u = unsigned(appid)
                for name in ("%dp.png", "%d.png", "%d_hero.png", "%d_logo.png", "%d.json", "%d_icon.png"):
                    p = os.path.join(grid, name % u)
                    if os.path.exists(p):
                        os.remove(p)
        for n, item in enumerate(root):
            item[1] = str(n)
        if ours:
            save_shortcuts(path, items)
        remove_layout(acc)
        print("Steam: Dekkimon removed (account %s)" % acc)
PYEOF
}

# ------------------------------------------------------------------------------------------
if [ "$MODE" = uninstall ]; then
    [ -d "$DEST" ] || [ -f "$DESKTOP_FILE" ] || die "Dekkimon is not installed in $DEST."
    app_running && die "Dekkimon is running. Close it first."
    if [ "$STEAM" = 1 ] && [ -n "$STEAM_ROOT" ]; then
        close_steam
        steam_tool uninstall "$STEAM_ROOT" "$DEST" "$APP_NAME" "$APP_ID_NAME" "$DEST/share" || warn "Steam cleanup failed."
    fi
    rm -f "$DESKTOP_FILE"
    if [ "$PURGE" = 1 ]; then
        rm -rf "$DEST"
        say "Dekkimon and all its settings were removed."
    else
        find "$DEST" -mindepth 1 -maxdepth 1 ! -name config -exec rm -rf {} +
        say "Dekkimon was removed. Your settings stay in $DEST/config (use --purge to delete them)."
    fi
    start_steam
    exit 0
fi

# --- get the package ----------------------------------------------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$TARBALL" ]; then
    [ -f "$TARBALL" ] || die "File not found: $TARBALL"
    tar -xzf "$TARBALL" -C "$WORK"
    PKG="$WORK/dekkimon"
elif [ -n "$SELF_DIR" ] && [ -x "$SELF_DIR/bin/dekkimon" ] && [ -f "$SELF_DIR/VERSION" ] && [ "$SELF_DIR" != "$DEST" ]; then
    PKG="$SELF_DIR"   # run from an extracted release package
else
    command -v curl >/dev/null || die "curl is missing."
    if [ -n "$VERSION" ]; then BASE="https://github.com/$REPO/releases/download/v${VERSION#v}"
    else BASE="https://github.com/$REPO/releases/latest/download"; fi
    say "Downloading Dekkimon ${VERSION:-(latest release)}"
    curl -fL --progress-bar -o "$WORK/$ASSET" "$BASE/$ASSET" || die "Download failed: $BASE/$ASSET"
    curl -fsSL -o "$WORK/SHA256SUMS" "$BASE/SHA256SUMS" || die "Download failed: $BASE/SHA256SUMS"
    (cd "$WORK" && grep " $ASSET\$" SHA256SUMS | sha256sum -c --quiet -) || die "Checksum mismatch: the download is damaged. Try again."
    tar -xzf "$WORK/$ASSET" -C "$WORK"
    PKG="$WORK/dekkimon"
fi
[ -x "$PKG/bin/dekkimon" ] || die "The package is incomplete (no bin/dekkimon)."
NEW_VERSION="$(cat "$PKG/VERSION")"

OLD_VERSION=""
[ -f "$DEST/VERSION" ] && OLD_VERSION="$(cat "$DEST/VERSION")"
app_running && die "Dekkimon is running. Close it first, then run the installer again."

if [ -n "$OLD_VERSION" ]; then say "Updating Dekkimon $OLD_VERSION -> $NEW_VERSION"
else say "Installing Dekkimon $NEW_VERSION in $DEST"; fi

# --- install files (settings, logs and developer files are kept) --------------------------
mkdir -p "$DEST"
for item in bin lib share; do
    rm -rf "$DEST/$item.new"
    cp -a "$PKG/$item" "$DEST/$item.new"
done
for item in bin lib share; do
    rm -rf "$DEST/$item.old"
    [ -e "$DEST/$item" ] && mv "$DEST/$item" "$DEST/$item.old"
    mv "$DEST/$item.new" "$DEST/$item"
    rm -rf "$DEST/$item.old"
done
for f in dekkimon.sh dekkimon-install.sh VERSION COPYING README.txt; do
    install -m "$( [ "${f##*.}" = sh ] && echo 755 || echo 644 )" "$PKG/$f" "$DEST/$f"
done

mkdir -p "$(dirname "$DESKTOP_FILE")"
cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
GenericName=Remote Play
Comment=PlayStation Remote Play for the Steam Deck
Exec="$DEST/dekkimon.sh"
Icon=$DEST/share/dekkimon-icon.png
Categories=Game;Network;RemoteAccess;
EOF
command -v update-desktop-database >/dev/null && update-desktop-database "$(dirname "$DESKTOP_FILE")" >/dev/null 2>&1 || true

# --- Steam --------------------------------------------------------------------------------
if [ "$STEAM" = 1 ]; then
    if [ -z "$STEAM_ROOT" ]; then
        warn "Steam was not found; skipping the Steam shortcut. Run the installer again after signing in to Steam."
    else
        close_steam
        flags=()
        [ "$RESET_CONTROLS" = 1 ] && flags+=(reset-controls)
        [ "$RESET_ARTWORK" = 1 ] && flags+=(reset-artwork)
        steam_tool install "$STEAM_ROOT" "$DEST" "$APP_NAME" "$APP_ID_NAME" "$DEST/share" "${flags[@]}" \
            | grep -v '^RUNGAMEID' || { start_steam; die "Adding Dekkimon to Steam failed. The app itself is installed in $DEST."; }
        start_steam
    fi
fi

echo
say "Dekkimon $NEW_VERSION is installed."
if [ "$STEAM" = 1 ] && [ -n "$STEAM_ROOT" ]; then
    echo "    Switch to Gaming Mode and open Library > Non-Steam to find Dekkimon."
fi
echo "    Update later:  run this installer again."
echo "    Uninstall:     bash $DEST/dekkimon-install.sh --uninstall"
