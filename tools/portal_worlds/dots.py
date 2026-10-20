#!/usr/bin/env python3
"""Export/review portable all-world dots from an existing native replay."""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parent


def digest(path):
    with path.open("rb") as source:
        result = hashlib.sha256()
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            result.update(chunk)
        return result.hexdigest()


def read(path):
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt") as source:
        for line in source:
            # Synced Lua may serialize integral IDs with a decimal suffix.
            def number(value):
                parsed = float(value)
                return int(parsed) if parsed.is_integer() else parsed

            yield json.loads(line, parse_float=number)


def region(header, x, z):
    for i, r in enumerate(header["regions"], 1):
        if r["x0"] <= x < r["x1"] and r["z0"] <= z < r["z1"]:
            return i
    return 0


def review(path):
    """Separate exact observations from heuristics requiring visual inspection."""
    header = None
    footer = None
    count = Counter()
    findings = defaultdict(list)
    last_frame = -1
    dwell = {}
    previous = {}
    last_transit = {}
    latest_units = {}
    maximum_units = 0
    for row in read(path):
        kind = row["type"]
        if footer is not None:
            raise ValueError("Rows after recording footer")
        if kind == "header":
            if header or row.get("format") != "portal-dots" or row.get("version") != 1:
                raise ValueError("Expected one portal-dots v1 header")
            header = row
            continue
        if header is None:
            raise ValueError("Missing recording header")
        if kind == "end":
            footer = row
            continue
        if kind == "event":
            count["events"] += 1
            count[row["kind"]] += 1
            data = row["data"]
            if row["kind"] == "transit":
                unit = latest_units.get(data["id"])
                definition = header["unit_defs"].get(str(unit[1])) if unit else None
                if definition:
                    count[
                        "air_transits" if definition["air"] else "ground_transits"
                    ] += 1
                    old = last_transit.get((unit[0], unit[15]))
                    if (
                        old
                        and old["data"]["from"] == data["to"]
                        and old["data"]["to"] == data["from"]
                        and row["frame"] - old["frame"] <= 300
                    ):
                        findings["rapid_return_candidates"].append(
                            {
                                "frame": row["frame"],
                                "id": data["id"],
                                "unit": definition["name"],
                                "team": unit[2],
                                "from": data["from"],
                                "to": data["to"],
                                "elapsed_frames": row["frame"] - old["frame"],
                            }
                        )
                    last_transit[(unit[0], unit[15])] = row
            if (
                row["kind"] == "damage"
                and data["source"]
                and data["region"]
                and data["source"] != data["region"]
            ):
                # An attacker can teleport after firing. Only immutable projectile
                # provenance establishes a foreign hit; position-only cases need review.
                key = (
                    "foreign_damage"
                    if data["source_kind"] == "projectile"
                    else "damage_position_candidates"
                )
                findings[key].append(row)
            continue
        if kind != "sample" or row["frame"] <= last_frame:
            raise ValueError("Unknown row or non-increasing sample frame")
        last_frame = row["frame"]
        count["samples"] += 1
        maximum_units = max(maximum_units, len(row["units"]))
        ids = set()
        for unit in row["units"]:
            if len(unit) != len(header["columns"]["units"]) or unit[0] in ids:
                raise ValueError("Invalid unit array or duplicate ID")
            ids.add(unit[0])
            latest_units[unit[0]] = unit
            (
                uid,
                definition,
                team,
                x,
                _,
                z,
                _,
                _,
                build,
                command,
                _,
                p1,
                p2,
                p3,
                physical,
                born,
            ) = unit
            unit_key = (uid, born)
            if physical != region(header, x, z):
                raise ValueError("Unit region disagrees with position")
            if physical == 0:
                count["unit_gap_samples"] += 1
                if len(findings["unit_gap_examples"]) < 20:
                    findings["unit_gap_examples"].append(
                        {"frame": last_frame, "unit": unit}
                    )
            # Coordinate commands only. Build headings, unit IDs and area-radius
            # commands must not be interpreted as move destinations.
            if (
                command in (10, 16, 20, 31109, 31110)
                and p1 is not False
                and p2 is not False
                and p3 is not False
            ):
                destination = region(header, p1, p3)
                if destination == 0:
                    count["gap_goal_samples"] += 1
                    if len(findings["gap_goal_examples"]) < 30:
                        findings["gap_goal_examples"].append(
                            {"frame": last_frame, "unit": unit}
                        )
            d = header["unit_defs"][str(definition)]
            r = header["regions"][physical - 1] if physical else None
            edge = r and min(x - r["x0"], r["x1"] - x, z - r["z0"], r["z1"] - z) < 64
            old = previous.get(unit_key)
            still = old and (x - old[0]) ** 2 + (z - old[1]) ** 2 < 4
            if (
                edge
                and still
                and build >= 0.99
                and d["speed"] > 0
                and not d["builder"]
                and command in (10, 16, 20, 31109, 31110)
            ):
                began = dwell.setdefault(unit_key, last_frame)
                if last_frame - began == 900:
                    findings["edge_dwell_candidates"].append(
                        {"frame": last_frame, "unit": unit, "seconds": 30}
                    )
            else:
                dwell.pop(unit_key, None)
            previous[unit_key] = (x, z)
        for shot in row["projectiles"]:
            if len(shot) != len(header["columns"]["projectiles"]):
                raise ValueError("Invalid projectile array")
            count["projectile_samples"] += 1
            if shot[7] and shot[8] and shot[7] != shot[8]:
                count["foreign_projectile_samples"] += 1
                if len(findings["foreign_projectile_examples"]) < 30:
                    findings["foreign_projectile_examples"].append(
                        {"frame": last_frame, "projectile": shot}
                    )
        # Drop dead/reused lifetimes to bound analysis memory.
        previous = {key: value for key, value in previous.items() if key[0] in ids}
        dwell = {key: value for key, value in dwell.items() if key[0] in ids}
    if header is None or footer is None or not count["samples"]:
        raise ValueError("Incomplete recording: missing header, samples or footer")
    if footer["samples"] != count["samples"] or footer["events"] != count["events"]:
        raise ValueError("Recording counts do not reconcile")
    return {
        "recording": str(path),
        "sha256": digest(path),
        "game": header.get("game"),
        "map": header["map"],
        "end_frame": footer["frame"],
        "reason": footer["reason"],
        "winners": footer.get("winners", []),
        "counts": dict(count),
        "maximum_units": maximum_units,
        "findings": dict(findings),
        "limits": "Half-second position/order samples; exact-frame damage and projectile births. Edge dwell and attacker-position differences are candidates, not proven bugs. No fog-of-war or visual particle reconstruction.",
    }


def demo_info(path):
    data = gzip.decompress(path.read_bytes())
    if len(data) < 352 or not data.startswith(b"spring demofile"):
        raise ValueError("Expected a Spring demo")
    version, size = struct.unpack_from("<ii", data, 16)
    script, stream, seconds = struct.unpack_from("<iii", data, 304)
    tail = sum(struct.unpack_from("<i", data, p)[0] for p in (324, 336, 348))
    if (
        version != 5
        or size < 352
        or min(script, stream, tail) < 0
        or not stream
        or size + script + stream + tail != len(data)
    ):
        raise ValueError("Unsupported or unfinished demo")
    offset, end, frame = size + script, size + script + stream, 0
    while offset < end:
        if offset + 8 > end:
            raise ValueError("Truncated demo packet")
        _, length = struct.unpack_from("<fI", data, offset)
        offset += 8
        if not length or offset + length > end:
            raise ValueError("Truncated demo packet")
        packet = data[offset : offset + length]
        offset += length
        if packet[0] == 1:
            if length != 5:
                raise ValueError("Invalid keyframe")
            frame = struct.unpack_from("<i", packet, 1)[0]
        elif packet[0] == 2:
            if length != 1:
                raise ValueError("Invalid newframe")
            frame += 1
    if frame <= 0:
        raise ValueError("No simulation frames")
    return {
        "sha256": digest(path),
        "last_frame": frame,
        "seconds": seconds,
        "engine_version": data[24:280].split(b"\0")[0].decode(),
    }


def capture(args):
    run, out = args.run.resolve(), args.out.resolve()
    demos = list((run / "write/demos").glob("*.sdfz"))
    if len(demos) != 1:
        raise ValueError("Expected one finalized replay in run/write/demos")
    demo = demos[0]
    info = demo_info(demo)
    engine = args.engine_dir.resolve()
    binary = engine / "spring-headless"
    version = subprocess.check_output(
        [str(binary), "--sync-version"], text=True
    ).strip()
    if version != info["engine_version"]:
        raise ValueError(
            f"Replay requires {info['engine_version']}; selected engine reports {version}"
        )
    limit = min(info["last_frame"], args.frames) if args.frames else info["last_frame"]
    out.parent.mkdir(parents=True, exist_ok=True)
    work = out.parent / (out.name + ".capture")
    if out.exists() or work.exists():
        raise ValueError("Choose a new output filename")
    work.mkdir()
    game = args.game_dir.resolve()
    overlay = work / "game.sdd"
    media = {
        ".dds",
        ".png",
        ".jpg",
        ".bmp",
        ".tga",
        ".s3o",
        ".3do",
        ".dae",
        ".ogg",
        ".wav",
        ".smt",
        ".smf",
        ".ttf",
        ".otf",
    }

    def copy(source, target):
        # Immutable original media is shared; every editable source is copied.
        if Path(source).suffix.lower() in media:
            try:
                return os.link(source, target)
            except OSError:
                pass
        return shutil.copy2(source, target)

    shutil.copytree(
        game,
        overlay,
        copy_function=copy,
        ignore=shutil.ignore_patterns(".git", "__pycache__"),
    )
    force = overlay / "tools/portal_worlds/dots/export.lua"
    force.write_text(
        f"-- Read-only replay capture clock.\nreturn {{enabled=true,end_frame={limit}}}\n"
    )
    iso, write = work / "isolation", work / "write"
    (iso / "games").mkdir(parents=True)
    write.mkdir()
    (iso / "games/game.sdd").symlink_to(overlay)
    for name in ("base", "fonts"):
        (iso / name).symlink_to(engine / name)
    (iso / "maps").symlink_to((run / "isolation/maps").resolve())
    # Replays contain the actual commands; no native AI libraries are loaded.
    (iso / "AI/Skirmish").mkdir(parents=True)
    control = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    control.bind(("127.0.0.1", 0))
    control.setblocking(False)
    config = work / "spring.conf"
    config.write_text(
        "Sound=0\nWorkerThreadCount=2\nUseLuaMemPools=0\nDemoFromDemo=0\nHangTimeout=120\n"
        f"AutohostIP=127.0.0.1\nAutohostPort={control.getsockname()[1]}\n"
    )
    command = [
        str(binary),
        "--isolation",
        "--isolation-dir",
        str(iso),
        "--write-dir",
        str(write),
        "--config",
        str(config),
        "--nocolor",
        str(demo),
    ]
    env = dict(
        os.environ,
        DISPLAY="",
        WAYLAND_DISPLAY="",
        SDL_VIDEODRIVER="offscreen",
        SDL_AUDIODRIVER="dummy",
    )
    receipt = {
        "replay": str(demo),
        "replay_info": info,
        "engine_version": version,
        "command": command,
        "source_game": str(game),
        "game_commit": subprocess.check_output(
            ["git", "-C", str(game), "rev-parse", "HEAD"], text=True
        ).strip(),
        "observer_sha256": digest(ROOT / "dots/recorder.lua"),
        "capture_end_frame": limit,
        "reference_trace_checked": False,
        "native_ai_present": False,
        "note": "Observer overlay changes the archive checksum. Validate gameplay against the source run; a loose replay is not a frozen-runtime proof.",
    }
    (work / "provenance.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Export log: {work / 'console.log'}", flush=True)
    started = time.monotonic()
    process = None
    success = False
    try:
        with (work / "console.log").open("w") as log:
            process = subprocess.Popen(
                ["nice", "-n", "10", *command],
                stdout=log,
                stderr=subprocess.STDOUT,
                env=env,
                start_new_session=True,
            )
            address = None
            while process.poll() is None:
                try:
                    while True:
                        _, address = control.recvfrom(65536)
                        control.sendto(f"/setmaxspeed {args.speed}".encode(), address)
                        control.sendto(f"/setminspeed {args.speed}".encode(), address)
                except BlockingIOError:
                    pass
                text = (work / "console.log").read_text(errors="replace")
                if any(
                    marker in text
                    for marker in (
                        "Failed to load: dbg_portal_recording.lua",
                        "Error in ",
                        "[DESYNC WARNING]",
                        "[LuaRules::RunCallInTraceback] error=",
                    )
                ):
                    raise RuntimeError("Replay/recorder error; see console.log")
                if "[PORTAL_DOTS] complete" in text:
                    success = True
                    break
                if time.monotonic() - started > args.seconds:
                    raise TimeoutError("Replay export timed out")
                time.sleep(0.5)
            success = success or "[PORTAL_DOTS] complete" in (
                work / "console.log"
            ).read_text(errors="replace")
    finally:
        control.close()
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        # This exact overlay is disposable; never remove source runs or media.
        shutil.rmtree(overlay)
    if not success:
        raise RuntimeError(f"No completed dots recording; see {work / 'console.log'}")
    logs = (work / "console.log").read_text(errors="replace")
    if "Error in " in logs or "[DESYNC WARNING]" in logs or "Sync error" in logs:
        raise RuntimeError("Replay reports Lua errors or desync; capture not accepted")
    recordings = list((write / "recordings").glob("*.jsonl"))
    if len(recordings) != 1:
        raise ValueError("Expected one observer output")
    report = review(recordings[0])
    with (
        recordings[0].open("rb") as source,
        gzip.open(out, "wb", compresslevel=6) as target,
    ):
        shutil.copyfileobj(source, target)
    report.update(recording=str(out), sha256=digest(out))
    (out.parent / (out.name + ".review.json")).write_text(
        json.dumps(report, indent=2) + "\n"
    )
    receipt.update(
        wall_seconds=time.monotonic() - started,
        recording_sha256=digest(out),
        end_frame=report["end_frame"],
    )
    (out.parent / (out.name + ".provenance.json")).write_text(
        json.dumps(receipt, indent=2) + "\n"
    )
    recordings[0].unlink()
    print(
        json.dumps(
            {
                "output": str(out),
                "counts": report["counts"],
                "findings": {k: len(v) for k, v in report["findings"].items()},
            },
            indent=2,
        )
    )


def presentation_copy(path, sample_frames):
    """Make a labelled display copy; retain the full recording for analysis."""
    import io

    stream = io.BytesIO()
    samples = 0
    previous = None
    with gzip.GzipFile(fileobj=stream, mode="wb", compresslevel=6) as target:

        def write(row):
            target.write(
                (
                    json.dumps(row, separators=(",", ":"), ensure_ascii=False) + "\n"
                ).encode()
            )

        for row in read(path):
            if row["type"] == "header":
                row["presentation"] = {
                    "source_sha256": digest(path),
                    "sample_frames": sample_frames,
                    "position_precision": 0.1,
                    "health_precision": 0.1,
                }
                row["sample_frames"] = sample_frames
                header = row
                write(row)
            elif row["type"] == "sample":
                previous = row
                if row["frame"] % sample_frames != 0:
                    continue
                for unit in row["units"]:
                    for index in (3, 4, 5, 6):
                        value = round(unit[index], 1)
                        if index in (3, 5) and unit[14]:
                            r = header["regions"][unit[14] - 1]
                            key = "x" if index == 3 else "z"
                            if not r[key + "0"] <= value < r[key + "1"]:
                                continue
                        unit[index] = value
                write(row)
                samples += 1
                previous = None
            elif row["type"] == "end":
                if previous is not None:
                    write(previous)
                    samples += 1
                row["samples"] = samples
                write(row)
            else:
                write(row)
    return stream.getvalue()


def main():
    def interrupted(_signal, _frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupted)
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    export = sub.add_parser(
        "export", help="Replay a completed launcher run headlessly; native AI absent"
    )
    export.add_argument("run", type=Path)
    export.add_argument("--out", type=Path, required=True)
    export.add_argument("--game-dir", type=Path, default=ROOT.parents[1])
    export.add_argument("--engine-dir", type=Path, required=True)
    export.add_argument("--frames", type=int, help="Export only a prefix")
    export.add_argument("--seconds", type=int, default=1800, help="Wall timeout")
    export.add_argument("--speed", type=float, default=30)
    check = sub.add_parser(
        "review", help="Validate recording and identify review candidates"
    )
    check.add_argument("recording", type=Path)
    pack = sub.add_parser(
        "pack", help="Validate and compress a completed live recording"
    )
    pack.add_argument("recording", type=Path)
    pack.add_argument("--out", type=Path, required=True)
    pack.add_argument("--run", type=Path, help="Launcher run directory for provenance")
    bundle = sub.add_parser(
        "bundle",
        help="Create one shareable offline HTML player with embedded recording",
    )
    bundle.add_argument("recording", type=Path)
    bundle.add_argument("--out", type=Path, required=True)
    bundle.add_argument(
        "--sample-frames",
        type=int,
        default=30,
        help="Display cadence in simulation frames; full source recording is preserved",
    )
    bundle.add_argument(
        "--map-dir",
        type=Path,
        help="Optional composed map for original minimap background",
    )
    args = parser.parse_args()
    if args.action == "export":
        capture(args)
    elif args.action == "pack":
        report = review(args.recording)
        if args.out.exists():
            parser.error("Output already exists")
        args.out.parent.mkdir(parents=True, exist_ok=True)
        opener = gzip.open if args.recording.suffix == ".gz" else open
        with (
            opener(args.recording, "rb") as source,
            gzip.open(args.out, "wb", compresslevel=6) as target,
        ):
            shutil.copyfileobj(source, target)
        report.update(recording=str(args.out), sha256=digest(args.out))
        args.out.with_name(args.out.name + ".review.json").write_text(
            json.dumps(report, indent=2) + "\n"
        )
        if args.run:
            provenance = json.loads((args.run / "command.json").read_text())
            provenance.update(
                source_recording=str(args.recording),
                source_sha256=digest(args.recording),
                recording_sha256=digest(args.out),
            )
            args.out.with_name(args.out.name + ".provenance.json").write_text(
                json.dumps(provenance, indent=2) + "\n"
            )
        print(args.out)
    elif args.action == "bundle":
        import base64

        review(args.recording)
        if args.out.exists():
            parser.error("Output already exists")
        if args.sample_frames < 15 or args.sample_frames % 15:
            parser.error(
                "--sample-frames must be a positive multiple of the native 15-frame cadence"
            )
        payload = presentation_copy(args.recording, args.sample_frames)
        image = ""
        if args.map_dir:
            import io
            from PIL import Image

            paths = list((args.map_dir / "maps").glob("*_minimap.png"))
            if len(paths) != 1:
                parser.error("Expected one native minimap PNG in map-dir/maps")
            target = io.BytesIO()
            with Image.open(paths[0]) as source:
                source.convert("RGB").save(target, format="JPEG", quality=85)
            image = (
                "data:image/jpeg;base64," + base64.b64encode(target.getvalue()).decode()
            )
        args.out.write_text(
            (ROOT / "dots/viewer.html")
            .read_text()
            .replace("__PORTAL_DOTS_DATA__", base64.b64encode(payload).decode())
            .replace("__PORTAL_MAP_IMAGE__", image)
        )
        args.out.with_name(args.out.name + ".provenance.json").write_text(
            json.dumps(
                {
                    "source_sha256": digest(args.recording),
                    "display_recording_sha256": hashlib.sha256(payload).hexdigest(),
                    "html_sha256": digest(args.out),
                    "viewer_sha256": digest(ROOT / "dots/viewer.html"),
                    "display_sample_frames": args.sample_frames,
                    "position_precision": 0.1,
                    "health_precision": 0.1,
                },
                indent=2,
            )
            + "\n"
        )
        print(args.out)
    else:
        print(json.dumps(review(args.recording), indent=2))


if __name__ == "__main__":
    main()
