#!/usr/bin/env python3
"""Run the policy matrix with an installed headless engine and development assets.

Example (from the BAR checkout):
  python3 tools/validation/reclaim_resurrection/run.py \
    --engine /path/to/spring-headless --base /path/to/engine/base \
    --assets /path/to/dev/data --output /path/to/results

Requires Quicksilver Remake 1.24 in assets/maps. Runs all five modoption values,
plus Fight/Patrol cases for each enabled policy. Each run uses an isolated
write directory, removes its asset overlay, and preserves logs and inputs.
"""

import argparse
import json
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time


def run(args, mode, scenario):
    out = args.output / f"{mode}-{scenario.stem}"
    out.mkdir(parents=True, exist_ok=False)
    shutil.copyfile(scenario, out / "scenario.lua")
    with tempfile.TemporaryDirectory(prefix="data-", dir=out) as temporary:
        data = Path(temporary)
        overlay = data / "games/test.sdd"
        (overlay / "luarules/gadgets").mkdir(parents=True)
        for name in ("maps", "packages", "pool"):
            source = args.assets / name
            if source.exists():
                (data / name).symlink_to(source)
        (data / "base").symlink_to(args.base)
        (data / "games/bar.sdd").symlink_to(args.game)
        (overlay / "modinfo.lua").write_text(
            'return {name="Reclaim Policy Validation",version="1",modtype=1,'
            'depend={"Beyond All Reason $VERSION"}}'
        )
        (overlay / "luaui.lua").write_text("")
        shutil.copyfile(scenario, overlay / "luarules/gadgets/test_policy.lua")
        script = """[GAME] {
 MapName=Quicksilver Remake 1.24; GameType=Reclaim Policy Validation 1;
 GameStartDelay=0; StartPosType=0; RecordDemo=0; MyPlayerName=Test;
 IsHost=1; HostIP=127.0.0.1; HostPort=0; FixedRNGSeed=1;
 [MODOPTIONS] { deathmode=neverend; experimental_reclaim_resurrection=POLICY; }
 [ALLYTEAM0] { NumAllies=0; } [ALLYTEAM1] { NumAllies=0; }
 [TEAM0] { AllyTeam=0; TeamLeader=0; }
 [TEAM1] { AllyTeam=0; TeamLeader=0; }
 [TEAM2] { AllyTeam=1; TeamLeader=0; }
 [PLAYER0] { Name=Test; Team=0; Spectator=1; }
} """
        (out / "input.txt").write_text(script.replace("POLICY", mode))
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind(("127.0.0.1", 0))
            sock.settimeout(0.2)
            config = out / "settings.cfg"
            config.write_text(
                "LuaUI = 0\nSound = 0\nWorkerThreadCount = 2\nPathingThreadCount = 1\n"
                f"AutohostIP = 127.0.0.1\nAutohostPort = {sock.getsockname()[1]}\n"
            )
            command = [
                str(args.engine), "--isolation", f"--isolation-dir={data}",
                f"--write-dir={data}", f"--config={config}", "--only-local",
                str(out / "input.txt"),
            ]
            (out / "command.json").write_text(json.dumps(command, indent=2))
            logfile = out / "engine.log"
            with logfile.open("w") as log:
                process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
                try:
                    start = time.monotonic()
                    peer = None
                    sent = set()
                    while process.poll() is None:
                        try:
                            _, peer = sock.recvfrom(65535)
                        except socket.timeout:
                            pass
                        elapsed = time.monotonic() - start
                        for delay, message in ((5, "/forcestart"), (7, "/setmaxspeed 50"), (8, "/setminspeed 50")):
                            if peer and elapsed > delay and message not in sent:
                                sock.sendto(message.encode(), peer)
                                sent.add(message)
                        content = logfile.read_text(errors="replace")
                        if "REZ_TEST|DIAG_DONE" in content or "LUA_ERRRUN" in content or elapsed > 180:
                            break
                finally:
                    if process.poll() is None:
                        process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            content = logfile.read_text(errors="replace")
            events = [line[line.index("REZ_TEST|"):] for line in content.splitlines() if "REZ_TEST|" in line]
            (out / "events.txt").write_text("\n".join(events) + "\n")
            if "REZ_TEST|DIAG_DONE" not in content or "LUA_ERRRUN" in content:
                raise RuntimeError(f"Validation failed: {logfile}")
            print(f"PASS {mode}/{scenario.stem}", flush=True)


def main():
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--assets", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--game", type=Path, default=root.parents[2])
    parser.add_argument("--mode", choices=("off", "first", "reclaim", "resurrect", "last"))
    args = parser.parse_args()
    for name in ("engine", "base", "assets", "output", "game"):
        setattr(args, name, getattr(args, name).resolve())
    for mode in ([args.mode] if args.mode else ("off", "first", "reclaim", "resurrect", "last")):
        run(args, mode, root / "scenario.lua")
        if mode != "off":
            run(args, mode, root / "fight.lua")


if __name__ == "__main__":
    main()
