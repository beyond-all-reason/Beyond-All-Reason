#!/usr/bin/env python3
"""Turn a headless aimfit roster run into gamedata/aim_from_estimates.lua.

    generate_aim_from_estimates.py --bar /path/to/Beyond-All-Reason results_roster.txt > gamedata/aim_from_estimates.lua
    generate_aim_from_estimates.py --bar /path/to/Beyond-All-Reason --check gamedata/aim_from_estimates.lua

The roster gadget (dbg_aimfit_roster.lua, modoption aimfit_roster=1) writes one
ROSTER line per unit weapon slot with out-of-sample errors of the current engine
behaviour (aimPre: the AimFromWeapon piece) and of the fitted estimate (full),
plus ROSTERPARAMS lines with the fitted numbers. A slot gets an entry
when the estimate is clearly better than the aim piece; everything else keeps the
engine's default behaviour.

--check recomputes the model/script fingerprints and exits 1 when any unit that
has an entry changed since the fit.
"""
import argparse
import hashlib
import os
import re
import subprocess
import sys
from collections import defaultdict

# quality gate, elmos
MIN_FIRED = 16
MIN_EVAL = 6
MIN_GAIN = 2.0          # aimPre mean error - estimate mean error
MAX_ESTIMATE_ERROR = 6.0

kv = re.compile(r"(\w+)=(\S+)")


def parse_results(path):
    rows = {}
    params = defaultdict(dict)   # (unit, w) -> piece -> (order, n, [7 floats])
    for line in open(path):
        line = line.strip()
        if line.startswith("AIMFIT ROSTER unit="):
            d = dict(kv.findall(line[len("AIMFIT ROSTER "):]))
            key = (d["unit"], int(d["w"]))
            def pair(v):
                a, b = v.split("/")
                return float(a), float(b)
            rows[key] = {
                "wd": d["wd"], "type": d["type"], "range": float(d["range"]),
                "fired": int(d["fired"]), "eval": int(d["eval"]),
                "barrels": [] if d["barrels"] == "-" else d["barrels"].split(","),
                "aimPre": pair(d["aimPre"]), "fixed": pair(d["fixed"]),
                "full": pair(d["full"]), "perPiece": pair(d["perPiece"]),
            }
        elif line.startswith("AIMFIT ROSTERPARAMS unit="):
            d = dict(kv.findall(line[len("AIMFIT ROSTERPARAMS "):]))
            key = (d["unit"], int(d["w"]))
            vals = [float(x) for x in d["params"].split(",")]
            params[key][d["piece"]] = (int(d.get("order", 0)), int(d["n"]), vals)
    return rows, params


def select(rows, params):
    """-> {unit: {slot: [7 floats]}} plus a report of every decision."""
    out = defaultdict(dict)
    report = []
    for (unit, w), r in sorted(rows.items()):
        aim = r["aimPre"][0]
        full = r["full"][0]
        pp = r["perPiece"][0]
        p = params.get((unit, w), {})
        reason = None
        if r["fired"] < MIN_FIRED or r["eval"] < MIN_EVAL:
            reason = f"too few shots ({r['fired']} fired, {r['eval']} eval)"
        elif "-" not in p:
            reason = "no parameters"
        else:
            # one tuple per weapon; barrels that alternate get the mean muzzle (which barrel
            # fires next cannot be predicted from the engine's QueryWeapon piece at aiming time)
            best = full
            if aim - best < MIN_GAIN:
                reason = f"no gain (aimPre {aim:.1f}, estimate {best:.1f})"
            elif best > MAX_ESTIMATE_ERROR:
                reason = f"estimate too loose ({best:.1f})"
            else:
                out[unit][w] = p["-"][2]
                barrels = f" ({len(r['barrels'])} barrels)" if len(r["barrels"]) >= 2 else ""
                report.append(f"{unit}:{w} aimPre {aim:.1f} -> {full:.1f}{barrels}")
        if reason:
            report.append(f"{unit}:{w} skipped: {reason}")
    return out, report


def unit_files(bar):
    """unit name -> (objectname, script) via lua, since the unit files are plain Lua tables."""
    lua = r"""
-- unit files may touch engine globals (e.g. Spring.GetModOptions().xmas); stub them
local stub = setmetatable({}, { __index = function() return function() return {} end end })
Spring, VFS, Game, Engine = stub, stub, {}, {}
local root = arg[1]
local p = io.popen('find "' .. root .. '/units" -name "*.lua"')
for f in p:lines() do
  local ok, t = pcall(dofile, f)
  if ok and type(t) == 'table' then
    for name, ud in pairs(t) do
      if type(ud) == 'table' then
        io.write(name, '\t', tostring(ud.objectname or ud.objectName or ''), '\t', tostring(ud.script or ''), '\n')
      end
    end
  end
end
"""
    res = subprocess.run(["lua5.1", "-", bar], input=lua, capture_output=True, text=True, check=True)
    files = {}
    for line in res.stdout.splitlines():
        name, obj, script = line.split("\t")
        files[name.lower()] = (obj, script)
    return files


def find_ci(root, rel):
    """case-insensitive lookup of rel under root"""
    cur = root
    for part in rel.replace("\\", "/").split("/"):
        if not part:
            continue
        try:
            names = os.listdir(cur)
        except OSError:
            return None
        match = next((n for n in names if n.lower() == part.lower()), None)
        if match is None:
            return None
        cur = os.path.join(cur, match)
    return cur if os.path.isfile(cur) else None


def fingerprint(bar, unit, files):
    obj, script = files.get(unit, ("", ""))
    h = hashlib.sha1()
    found = 0
    if not obj and not script:
        # def file could not be evaluated offline: hash the unit definition file itself
        for dirpath, _, names in os.walk(os.path.join(bar, "units")):
            for n in names:
                if n.lower() == unit.lower() + ".lua":
                    with open(os.path.join(dirpath, n), "rb") as f:
                        h.update(b"def:" + f.read())
                    found += 1
    for base, rel in (("objects3d", obj), ("scripts", script)):
        if not rel:
            continue
        path = find_ci(os.path.join(bar, base), rel)
        if path is None and base == "scripts" and not rel.lower().endswith(".lua"):
            path = find_ci(os.path.join(bar, base), re.sub(r"\.cob$", ".lua", rel, flags=re.I))
        if path is None and base == "scripts" and not rel.lower().endswith(".cob"):
            path = find_ci(os.path.join(bar, base), re.sub(r"\.lua$", ".cob", rel, flags=re.I))
        if path is None:
            h.update(b"missing:" + rel.encode())
            continue
        found += 1
        with open(path, "rb") as f:
            h.update(f.read())
    return h.hexdigest() if found else None


def fmt_nums(vals):
    return ", ".join(f"{v:.2f}" for v in vals)


def write_lua(selected, fps, out):
    out.write("-- Generated by tools/aimfit/generate_aim_from_estimates.py from a headless fitting run\n")
    out.write("-- (see tools/aimfit/README.md). Do not edit by hand: rerun the tool after changing a\n")
    out.write("-- unit's model or script; `--check` reports units whose fingerprint no longer matches.\n")
    out.write("--\n")
    out.write("-- weapons[unitName][weaponSlot] = {pivotX, pivotY, pivotZ, lateral, forward, barrelForward, barrelUp}\n")
    out.write("--   in unit space (yaw pivot, offsets turning with yaw only, offsets turning with yaw and\n")
    out.write("--   pitch); weapons that alternate between barrels get the mean muzzle. Consumed by the\n")
    out.write("--   engine's aimFromEstimate weapon tag; applied in unitdefs_post.lua unless the unit file\n")
    out.write("--   sets its own.\n")
    out.write("-- fingerprints[unitName] = sha1 of the unit's model and script files at fitting time.\n")
    out.write("return {\n\tweapons = {\n")
    for unit in sorted(selected):
        slots = selected[unit]
        parts = []
        for w in sorted(slots):
            est = slots[w]
            parts.append(f"[{w}] = {{ {fmt_nums(est)} }}")
        out.write(f"\t\t{unit} = {{ {', '.join(parts)} }},\n")
    out.write("\t},\n\tfingerprints = {\n")
    for unit in sorted(selected):
        out.write(f'\t\t{unit} = "{fps.get(unit) or "?"}",\n')
    out.write("\t},\n}\n")


def read_lua_fingerprints(path):
    text = open(path).read()
    block = text[text.index("fingerprints = {"):]
    return dict(re.findall(r'(\w+) = "([0-9a-f?]+)"', block))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("--bar", required=True, help="Beyond-All-Reason checkout")
    ap.add_argument("--check", action="store_true", help="input is the generated Lua file; verify fingerprints")
    ap.add_argument("--report", help="write the selection report here")
    args = ap.parse_args()

    files = unit_files(args.bar)

    if args.check:
        stale = []
        for unit, fp in sorted(read_lua_fingerprints(args.input).items()):
            now = fingerprint(args.bar, unit, files)
            if now != fp:
                stale.append(unit)
        if stale:
            print("aimFromEstimate values are stale for:", ", ".join(stale), file=sys.stderr)
            print("rerun tools/aimfit (see tools/aimfit/README.md) for these units", file=sys.stderr)
            sys.exit(1)
        print("aim_from_estimates.lua fingerprints match")
        return

    rows, params = parse_results(args.input)
    selected, report = select(rows, params)
    fps = {u: fingerprint(args.bar, u, files) for u in selected}
    for u, fp in fps.items():
        if fp is None:
            print(f"warning: no fingerprint for {u} (model/script/def file not found)", file=sys.stderr)
    write_lua(selected, fps, sys.stdout)
    if args.report:
        with open(args.report, "w") as f:
            f.write("\n".join(report) + "\n")
    print(f"{sum(len(s) for s in selected.values())} slots on {len(selected)} units selected from {len(rows)} measured",
          file=sys.stderr)


if __name__ == "__main__":
    main()
