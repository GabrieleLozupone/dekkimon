"""Installer test in a fake home folder (no Steam, no network).

    python3 test/installer/test_installer.py dist/dekkimon-steamdeck.tar.gz

Covers: fresh install, update keeping settings, migrating a legacy "Dekkimon" shortcut that
points at ~/Applications/chiaki-portal, other shortcuts left untouched, artwork, Steam Input
layout + configset entry, uninstall (keeps settings) and --purge.
"""
import os, re, shutil, struct, subprocess, sys, tempfile, zlib
from pathlib import Path

TARBALL = Path(sys.argv[1]).resolve()
INSTALLER = Path(__file__).resolve().parents[2] / "installer" / "dekkimon-install.sh"
ACC = "123456"


def cstr(s):
    return s.encode() + b"\0"


def entry(idx, appid, name, exe, extra=b""):
    body = (b"\x02appid\0" + struct.pack("<i", appid) + b"\x01appname\0" + cstr(name)
            + b"\x01Exe\0" + cstr(exe) + b"\x01StartDir\0" + cstr("/") + b"\x01icon\0" + cstr("")
            + extra + b"\x00tags\0\x08")
    return b"\x00" + cstr(str(idx)) + body + b"\x08"


def read_vdf(path):
    sys.path.insert(0, str(Path(__file__).parent))
    b = path.read_bytes()
    out, i = [], 0
    # minimal reader: list of (appid, name, exe) per entry
    for m in re.finditer(rb"\x02appid\x00(.{4})\x01(?:appname|AppName)\x00([^\x00]*)\x00\x01Exe\x00([^\x00]*)\x00", b, re.S):
        out.append((struct.unpack("<i", m.group(1))[0] & 0xffffffff, m.group(2).decode(), m.group(3).decode()))
    return out


def run(home, *args, ok=True):
    env = dict(os.environ, HOME=str(home), PATH=os.environ["PATH"])
    r = subprocess.run(["bash", str(INSTALLER), "--tarball", str(TARBALL), "--yes", *args],
                       env=env, capture_output=True, text=True)
    if ok and r.returncode != 0:
        print(r.stdout, r.stderr)
        raise SystemExit("installer failed: %s" % (args,))
    return r


def make_home(legacy):
    home = Path(tempfile.mkdtemp())
    steam = home / ".local/share/Steam"
    cfg = steam / "userdata" / ACC / "config"
    cfg.mkdir(parents=True)
    (steam / "config").mkdir()
    (steam / "config/loginusers.vdf").write_text(
        '"users"\n{\n\t"%d"\n\t{\n\t\t"AccountName"\t\t"x"\n\t\t"MostRecent"\t\t"1"\n\t}\n}\n' % (76561197960265728 + int(ACC)))
    shortcuts = entry(0, -100, "Some Game", '"/usr/bin/somegame"')
    if legacy:
        shortcuts += entry(1, 2888559312 - (1 << 32), "Dekkimon", '"/home/deck/Applications/chiaki-portal/chiaki-portal.sh"')
    (cfg / "shortcuts.vdf").write_bytes(b"\x00shortcuts\0" + shortcuts + b"\x08\x08")
    cc = steam / "steamapps/common/Steam Controller Configs" / ACC / "config"
    cc.mkdir(parents=True)
    (cc / "configset_controller_neptune.vdf").write_text('"controller_config"\n{\n\t"some game"\n\t{\n\t\t"template"\t\t"x.vdf"\n\t}\n}\n')
    if legacy:
        (cc / "dekkimon").mkdir()
        (cc / "dekkimon/controller_neptune.vdf").write_text("user customised layout")
        old = home / "Applications/chiaki-portal/config/Chiaki"
        old.mkdir(parents=True)
        (old / "Chiaki.conf").write_text("[General]\nlegacy=1\n")
    return home, steam, cfg, cc


# 1) fresh install
home, steam, cfg, cc = make_home(legacy=False)
run(home)
dest = home / "Applications/dekkimon"
assert (dest / "bin/dekkimon").exists() and os.access(dest / "dekkimon.sh", os.X_OK)
entries = read_vdf(cfg / "shortcuts.vdf")
assert len(entries) == 2, entries
assert entries[0][1] == "Some Game"
appid, name, exe = entries[1]
assert name == "Dekkimon" and exe == '"%s/dekkimon.sh"' % dest, entries
expected = (zlib.crc32(('"%s/dekkimon.sh"' % dest + "Dekkimon").encode()) | 0x80000000)
assert appid == expected, (appid, expected)
for n in ("%dp.png", "%d.png", "%d_hero.png", "%d_logo.png", "%d.json"):
    assert (cfg / "grid" / (n % appid)).exists(), n
assert (cc / "dekkimon/controller_neptune.vdf").exists()
cs = (cc / "configset_controller_neptune.vdf").read_text()
assert '"dekkimon"' in cs and '"some game"' in cs, cs
assert (home / ".local/share/applications/dekkimon.desktop").exists()

# 2) update: settings and a customised layout are kept, no duplicate shortcut or configset
(dest / "config/Chiaki").mkdir(parents=True)
(dest / "config/Chiaki/Chiaki.conf").write_text("keep")
(cc / "dekkimon/controller_neptune.vdf").write_text("customised")
run(home)
assert (dest / "config/Chiaki/Chiaki.conf").read_text() == "keep"
assert (cc / "dekkimon/controller_neptune.vdf").read_text() == "customised"
assert len(read_vdf(cfg / "shortcuts.vdf")) == 2
assert (cc / "configset_controller_neptune.vdf").read_text().count('"dekkimon"') == 1
run(home, "--reset-controls")
assert (cc / "dekkimon/controller_neptune.vdf").read_text() != "customised"

# 3) uninstall keeps settings, then purge
run(home, "--uninstall")
assert [e[1] for e in read_vdf(cfg / "shortcuts.vdf")] == ["Some Game"]
assert not list((cfg / "grid").glob("%d*" % appid))
assert not (cc / "dekkimon").exists() and '"dekkimon"' not in (cc / "configset_controller_neptune.vdf").read_text()
assert '"some game"' in (cc / "configset_controller_neptune.vdf").read_text()
assert (dest / "config/Chiaki/Chiaki.conf").exists() and not (dest / "bin").exists()
assert not (home / ".local/share/applications/dekkimon.desktop").exists()
run(home, "--uninstall", "--purge")
assert not dest.exists()
shutil.rmtree(home)

# 4) legacy shortcut is migrated in place (same appid, layout kept), settings imported on launch
home, steam, cfg, cc = make_home(legacy=True)
run(home)
entries = read_vdf(cfg / "shortcuts.vdf")
assert len(entries) == 2, entries
assert entries[1][0] == 2888559312 and entries[1][2] == '"%s/dekkimon.sh"' % (home / "Applications/dekkimon"), entries
assert (cc / "dekkimon/controller_neptune.vdf").read_text() == "user customised layout"
assert (cfg / "grid/2888559312p.png").exists()
# The launcher's one-time import (run with a stub binary so nothing starts).
dest = home / "Applications/dekkimon"
(dest / "bin/dekkimon").write_text("#!/bin/sh\nexit 0\n")
subprocess.run(["bash", str(dest / "dekkimon.sh")], env=dict(os.environ, HOME=str(home)), check=True)
assert (dest / "config/Chiaki/Chiaki.conf").read_text() == "[General]\nlegacy=1\n"
assert (dest / ".legacy-imported").exists()
shutil.rmtree(home)
print("installer: all checks passed")
