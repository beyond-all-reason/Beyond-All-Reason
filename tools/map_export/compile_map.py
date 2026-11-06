#!/usr/bin/env python3
"""Map export, binary step: an export folder -> .smf + .smt -> one .sd7 map archive.

The Lua step (common/map_export.lua, FILE > Export Map... or tools/map_export/export.lua) writes

    <export>/archive/            every text file and texture the map archive ships
    <export>/compile/            compile.json + heightmap.png, minimap.png, diffuse/sq_X_Z.png

This step reads compile/, writes archive/maps/<base>.smf and <base>.smt, then packs archive/ into
<export>/<base>.sd7 (7-Zip) or <base>.sdz (zip, when 7-Zip is missing or asked for). archive/ on its own is
also a working map folder: rename it <base>.sdd and drop it in maps/ to test without packing.

Formats: rts/Map/SMF/SMFFormat.h in the engine. Tiles and the minimap are DXT1, encoded here (numpy), so
nothing beyond numpy and Pillow is needed. Same input gives the same bytes (mapid is a hash of the name).

    python tools/map_export/compile_map.py <export folder> [--format sd7|sdz|none] [--seven-zip PATH]

Exit code 1 on errors. Writes <export>/compile_report.txt.
"""

import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import zipfile
import zlib

import numpy as np
from PIL import Image

FORMAT_VERSION = 1  # compile.json versions this reads
SQUARE = 8  # elmos per heightmap square, fixed by the engine
TEXELS_PER_SQUARE = 8
TILE = 32  # texels per tile side
TILE_MIPS = 4  # 32, 16, 8, 4
TILE_BYTES = sum((TILE >> m) ** 2 // 2 for m in range(TILE_MIPS))  # 680
MINIMAP = 1024
MINIMAP_MIPS = 9  # 1024 .. 4
MINIMAP_BYTES = 699048
HEADER = struct.Struct("<16s i i i i i i i f f i i i i i i i")  # SMFHeader, 80 bytes
TILE_FILE_HEADER = struct.Struct("<16s i i i i")  # TileFileHeader, 32 bytes


class CompileError(Exception):
    pass


# DXT1 ---------------------------------------------------------------------------------------------


def _to565(c):
    """float RGB (..., 3) in 0..255 -> uint16 RGB565, rounded."""
    c = np.clip(c, 0, 255)
    r = np.rint(c[..., 0] * 31 / 255).astype(np.uint16)
    g = np.rint(c[..., 1] * 63 / 255).astype(np.uint16)
    b = np.rint(c[..., 2] * 31 / 255).astype(np.uint16)
    return (r << 11) | (g << 5) | b


def _from565(v):
    """uint16 RGB565 -> float RGB (..., 3) as a decoder expands it."""
    v = v.astype(np.int32)
    r = (v >> 11) & 31
    g = (v >> 5) & 63
    b = v & 31
    return np.stack([(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)], axis=-1).astype(np.float32)


def _encode_blocks(px):
    """px: (N, 16, 3) float32 -> (N, 8) uint8 DXT1 blocks (4-colour mode).

    Endpoints: the block's extreme pixels along its principal axis (stb_dxt's approach), then one
    least-squares refit of the endpoints to the chosen indices."""
    n = px.shape[0]
    mean = px.mean(axis=1, keepdims=True)
    d = px - mean
    cov = np.einsum("nki,nkj->nij", d, d)
    axis = np.ones((n, 3), np.float32)
    for _ in range(6):
        axis = np.einsum("nij,nj->ni", cov, axis)
        norm = np.linalg.norm(axis, axis=1, keepdims=True)
        axis = np.where(norm > 1e-6, axis / np.maximum(norm, 1e-6), np.float32(0.57735))
    proj = np.einsum("nki,ni->nk", d, axis)
    lo = px[np.arange(n), proj.argmin(axis=1)]
    hi = px[np.arange(n), proj.argmax(axis=1)]

    def pick(c0, c1):
        p0, p1 = _from565(_to565(c0)), _from565(_to565(c1))
        pal = np.stack([p0, p1, (2 * p0 + p1) / 3, (p0 + 2 * p1) / 3], axis=1)  # (N, 4, 3)
        dist = ((px[:, :, None, :] - pal[:, None, :, :]) ** 2).sum(axis=-1)  # (N, 16, 4)
        idx = dist.argmin(axis=-1)
        return idx, np.take_along_axis(dist, idx[..., None], axis=-1)[..., 0].sum(axis=1)

    idx, err = pick(hi, lo)

    # refit: px ~ a*c0 + b*c1 with (a, b) the palette weights of each pixel's index
    w = np.array([[1, 0], [0, 1], [2 / 3, 1 / 3], [1 / 3, 2 / 3]], np.float32)[idx]  # (N, 16, 2)
    ata = np.einsum("nki,nkj->nij", w, w)
    atb = np.einsum("nki,nkc->nic", w, px)
    det = ata[:, 0, 0] * ata[:, 1, 1] - ata[:, 0, 1] * ata[:, 1, 0]
    ok = np.abs(det) > 1e-6
    inv = np.zeros_like(ata)
    sd = np.where(ok, det, 1)
    inv[:, 0, 0] = ata[:, 1, 1] / sd
    inv[:, 1, 1] = ata[:, 0, 0] / sd
    inv[:, 0, 1] = -ata[:, 0, 1] / sd
    inv[:, 1, 0] = -ata[:, 1, 0] / sd
    ends = np.einsum("nij,njc->nic", inv, atb)
    idx2, err2 = pick(ends[:, 0], ends[:, 1])
    better = ok & (err2 < err)
    c0f = np.where(better[:, None], ends[:, 0], hi)
    c1f = np.where(better[:, None], ends[:, 1], lo)
    idx = np.where(better[:, None], idx2, idx)

    c0 = _to565(c0f)
    c1 = _to565(c1f)
    # 4-colour mode needs c0 > c1; swapping the ends swaps index 0<->1 and 2<->3
    swap = c0 < c1
    c0, c1 = np.where(swap, c1, c0), np.where(swap, c0, c1)
    idx = np.where(swap[:, None], idx ^ 1, idx)
    # equal ends: the decoder is in 3-colour mode, where index 0 is still c0
    idx = np.where((c0 == c1)[:, None], 0, idx)

    bits = (idx.astype(np.uint32) << (2 * np.arange(16, dtype=np.uint32))).sum(axis=1, dtype=np.uint64)
    out = np.empty((n, 8), np.uint8)
    out[:, 0:2] = c0.astype("<u2").view(np.uint8).reshape(n, 2)
    out[:, 2:4] = c1.astype("<u2").view(np.uint8).reshape(n, 2)
    out[:, 4:8] = bits.astype("<u4").view(np.uint8).reshape(n, 4)
    return out


def dxt1(img, strip_rows=256):
    """img: (H, W, 3) uint8, H and W multiples of 4 -> (H/4, W/4, 8) uint8 blocks."""
    h, w, _ = img.shape
    if h % 4 or w % 4:
        raise CompileError(f"DXT1 needs sizes in multiples of 4, got {w}x{h}")
    out = np.empty((h // 4, w // 4, 8), np.uint8)
    for y in range(0, h, strip_rows):
        strip = img[y : y + strip_rows].astype(np.float32)
        sh = strip.shape[0]
        blocks = strip.reshape(sh // 4, 4, w // 4, 4, 3).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 3)
        out[y // 4 : (y + sh) // 4] = _encode_blocks(blocks).reshape(sh // 4, w // 4, 8)
    return out


def dxt1_decode(blocks):
    """(H/4, W/4, 8) uint8 -> (H, W, 3) uint8. For tests and the report's quality figure."""
    bh, bw, _ = blocks.shape
    flat = blocks.reshape(-1, 8)
    c0 = flat[:, 0:2].copy().view("<u2")[:, 0]
    c1 = flat[:, 2:4].copy().view("<u2")[:, 0]
    bits = flat[:, 4:8].copy().view("<u4")[:, 0]
    p0, p1 = _from565(c0), _from565(c1)
    four = (c0 > c1)[:, None]
    p2 = np.where(four, (2 * p0 + p1) / 3, (p0 + p1) / 2)
    p3 = np.where(four, (p0 + 2 * p1) / 3, 0)
    pal = np.stack([p0, p1, p2, p3], axis=1)
    idx = (bits[:, None] >> (2 * np.arange(16, dtype=np.uint32))) & 3
    px = np.take_along_axis(pal, idx[..., None].astype(np.int64), axis=1)
    img = px.reshape(bh, bw, 4, 4, 3).transpose(0, 2, 1, 3, 4).reshape(bh * 4, bw * 4, 3)
    return np.clip(np.rint(img), 0, 255).astype(np.uint8)


def half(img):
    """2x2 box filter; (H, W, 3) uint8 with even sizes."""
    f = img.astype(np.float32)
    f = (f[0::2, 0::2] + f[1::2, 0::2] + f[0::2, 1::2] + f[1::2, 1::2]) / 4
    return np.rint(f).astype(np.uint8)


# Inputs -------------------------------------------------------------------------------------------


def load_rgb(path):
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"))


def resize_rgb(arr, w, h):
    if arr.shape[1] == w and arr.shape[0] == h:
        return arr
    return np.asarray(Image.fromarray(arr).resize((w, h), Image.BICUBIC))


def load_heightmap(path, w, h, notes):
    with Image.open(path) as im:
        if im.mode in ("I;16", "I;16B", "I;16L", "I"):
            arr = np.asarray(im, dtype=np.uint32).astype(np.float64)
            if im.mode == "I" and arr.max() > 65535:
                raise CompileError("heightmap.png: values above 16 bits")
        elif im.mode in ("L", "RGB", "RGBA"):
            arr = np.asarray(im.convert("L"), dtype=np.float64) * 257
            notes.append("heightmap.png is 8-bit: steps of 1/255 of the height range")
        else:
            raise CompileError(f"heightmap.png: unsupported mode {im.mode}")
    if arr.shape != (h, w):
        notes.append(f"heightmap.png is {arr.shape[1]}x{arr.shape[0]}, resized to {w}x{h}")
        f = Image.fromarray(arr.astype(np.float32), mode="F").resize((w, h), Image.BILINEAR)
        arr = np.asarray(f, dtype=np.float64)
    return np.clip(np.rint(arr), 0, 65535).astype("<u2")


def diffuse_texture(spec, compile_dir, tex_w, tex_h, minimap, notes):
    """Full-resolution ground texture (1 texel per elmo): captured squares over a base.

    The base is the minimap stretched up when there is one (the map as the editor drew it, blurry), else
    the flat base colour. Squares cover what was captured."""
    d = spec.get("diffuse") or {}
    base = d.get("base_color") or [110, 130, 90]
    squares = d.get("squares") or []
    if minimap is not None:
        img = resize_rgb(minimap, tex_w, tex_h).copy()
        source = "minimap stretched to full size"
    else:
        img = np.empty((tex_h, tex_w, 3), np.uint8)
        img[:] = np.array(base[:3], np.uint8)
        source = "flat base colour"
    sq = int(d.get("square_size") or 1024)
    placed = 0
    for sx, sz in squares:
        path = os.path.join(compile_dir, "diffuse", f"sq_{sx}_{sz}.png")
        if not os.path.isfile(path):
            notes.append(f"diffuse square {sx},{sz} listed but missing")
            continue
        x0, z0 = sx * sq, sz * sq
        if x0 >= tex_w or z0 >= tex_h:
            notes.append(f"diffuse square {sx},{sz} lies outside the map, skipped")
            continue
        w, h = min(sq, tex_w - x0), min(sq, tex_h - z0)
        img[z0 : z0 + h, x0 : x0 + w] = resize_rgb(load_rgb(path), sq, sq)[:h, :w]
        placed += 1
    if squares:
        source = f"{placed} captured square(s) over the {source}"
    return img, source


# Writers ------------------------------------------------------------------------------------------


def build_tiles(img):
    """Ground texture -> (unique tiles as bytes, int32 index grid [tilesZ, tilesX])."""
    h, w, _ = img.shape
    ty, tx = h // TILE, w // TILE
    levels = []
    level = img
    for m in range(TILE_MIPS):
        n = (TILE >> m) // 4  # blocks per tile side at this level
        blocks = dxt1(level)  # (ty*n, tx*n, 8)
        levels.append(blocks.reshape(ty, n, tx, n, 8).transpose(0, 2, 1, 3, 4).reshape(ty, tx, n * n * 8))
        if m + 1 < TILE_MIPS:
            level = half(level)
    tiles = np.concatenate(levels, axis=2).reshape(ty * tx, TILE_BYTES)
    view = np.ascontiguousarray(tiles).view(np.dtype((np.void, TILE_BYTES)))[:, 0]
    uniq, first, inverse = np.unique(view, return_index=True, return_inverse=True)
    # keep tiles in first-seen order so the file reads top-left to bottom-right
    order = np.argsort(first)
    rank = np.empty_like(order)
    rank[order] = np.arange(len(order))
    return tiles[first[order]], rank[inverse].reshape(ty, tx).astype("<i4")


def build_minimap(minimap_rgb):
    img = resize_rgb(minimap_rgb, MINIMAP, MINIMAP)
    parts = []
    for m in range(MINIMAP_MIPS):
        parts.append(dxt1(img).tobytes())
        if m + 1 < MINIMAP_MIPS:
            img = half(img)
    data = b"".join(parts)
    assert len(data) == MINIMAP_BYTES, len(data)
    return data


def metal_grid(spec, mw, mh, notes):
    grid = np.zeros((mh, mw), np.uint8)
    metal = spec.get("metal")
    if not metal:
        return grid, 0
    if metal.get("width") not in (None, mw) or metal.get("height") not in (None, mh):
        notes.append(f"metal grid is {metal.get('width')}x{metal.get('height')}, the map's is {mw}x{mh}; cells outside dropped")
    n = 0
    for mx, mz, b in metal.get("cells") or []:
        if 0 <= mx < mw and 0 <= mz < mh:
            grid[mz, mx] = max(0, min(255, int(b)))
            n += 1
    return grid, n


def write_smf(path, *, mapid, mapx, mapy, minh, maxh, heights, typemap, minimap, metal, tile_index, smt_name, num_tiles):
    tile_section = (
        struct.pack("<ii", 1, num_tiles)
        + struct.pack("<i", num_tiles)
        + smt_name.encode("ascii")
        + b"\0"
        + tile_index.tobytes()
    )
    features = struct.pack("<ii", 0, 0)  # placements ship in mapconfig/featureplacer/set.lua
    chunks = [heights.tobytes(), typemap.tobytes(), tile_section, minimap, metal.tobytes(), features]
    offsets = []
    pos = HEADER.size
    for c in chunks:
        offsets.append(pos)
        pos += len(c)
    header = HEADER.pack(
        b"spring map file\0",
        1,
        mapid,
        mapx,
        mapy,
        SQUARE,
        TEXELS_PER_SQUARE,
        TILE,
        float(minh),
        float(maxh),
        offsets[0],  # heightmap
        offsets[1],  # type map
        offsets[2],  # tiles
        offsets[3],  # minimap
        offsets[4],  # metal map
        offsets[5],  # features
        0,  # extra headers: grass ships as mapinfo.custom.grassConfig + grass_dist.tga
    )
    with open(path, "wb") as f:
        f.write(header)
        for c in chunks:
            f.write(c)
    return pos


def write_smt(path, tiles):
    with open(path, "wb") as f:
        f.write(TILE_FILE_HEADER.pack(b"spring tilefile\0", 1, len(tiles), TILE, 1))
        f.write(tiles.tobytes())
    return TILE_FILE_HEADER.size + tiles.nbytes


def read_smf_header(path):
    with open(path, "rb") as f:
        return HEADER.unpack(f.read(HEADER.size))


# Packing ------------------------------------------------------------------------------------------


def find_seven_zip(explicit):
    for c in [explicit, shutil.which("7z"), shutil.which("7za"), r"C:\Program Files\7-Zip\7z.exe"]:
        if c and os.path.isfile(c):
            return c
    return None


def archive_files(archive_dir):
    out = []
    for root, _, files in os.walk(archive_dir):
        for name in files:
            full = os.path.join(root, name)
            out.append(os.path.relpath(full, archive_dir).replace(os.sep, "/"))
    return sorted(out)


def pack(archive_dir, out_path, fmt, seven_zip):
    if os.path.exists(out_path):
        os.remove(out_path)
    if fmt == "sd7":
        listfile = out_path + ".list"
        with open(listfile, "w", encoding="utf-8") as f:
            f.write("\n".join(archive_files(archive_dir)) + "\n")
        try:
            r = subprocess.run(
                [seven_zip, "a", "-t7z", "-mx=5", "-bd", "-y", os.path.abspath(out_path), "@" + os.path.abspath(listfile)],
                cwd=archive_dir,
                capture_output=True,
                text=True,
            )
        finally:
            os.remove(listfile)
        if r.returncode != 0:
            raise CompileError("7-Zip failed:\n" + (r.stdout + r.stderr).strip())
    else:
        with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as z:
            for rel in archive_files(archive_dir):
                info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                with open(os.path.join(archive_dir, rel), "rb") as src:
                    z.writestr(info, src.read())


# Main ---------------------------------------------------------------------------------------------


def compile_export(export_dir, fmt="sd7", seven_zip=None, log=print):
    compile_dir = os.path.join(export_dir, "compile")
    archive_dir = os.path.join(export_dir, "archive")
    spec_path = os.path.join(compile_dir, "compile.json")
    if not os.path.isfile(spec_path):
        raise CompileError(f"no compile/compile.json in {export_dir}: run the export first")
    with open(spec_path, encoding="utf-8") as f:
        spec = json.load(f)
    if spec.get("format_version") != FORMAT_VERSION:
        raise CompileError(f"compile.json format_version {spec.get('format_version')}, this compiler reads {FORMAT_VERSION}")

    notes = []
    report = {"name": spec.get("name"), "notes": notes, "files": []}
    size_x, size_z = int(spec["size_x"]), int(spec["size_z"])
    if size_x < 1 or size_z < 1:
        raise CompileError(f"bad map size {size_x}x{size_z}")
    mapx, mapy = size_x * 64, size_z * 64
    height = spec.get("height") or {}
    if "min" not in height or "max" not in height:
        raise CompileError("compile.json has no height range")
    if not spec.get("heightmap"):
        raise CompileError("compile.json names no heightmap")

    log(f"map {spec.get('name')}: {size_x}x{size_z} ({mapx * SQUARE}x{mapy * SQUARE} elmos)")
    heights = load_heightmap(os.path.join(compile_dir, spec["heightmap"]), mapx + 1, mapy + 1, notes)

    minimap_rgb = None
    if spec.get("minimap") and os.path.isfile(os.path.join(compile_dir, spec["minimap"])):
        minimap_rgb = load_rgb(os.path.join(compile_dir, spec["minimap"]))

    tex_w, tex_h = mapx * TEXELS_PER_SQUARE, mapy * TEXELS_PER_SQUARE
    log(f"ground texture {tex_w}x{tex_h}...")
    ground, ground_source = diffuse_texture(spec, compile_dir, tex_w, tex_h, minimap_rgb, notes)
    if minimap_rgb is None:
        minimap_rgb = resize_rgb(ground, MINIMAP, MINIMAP)
        notes.append("no minimap.png: the minimap is the ground texture scaled down")

    log("tiles (DXT1)...")
    tiles, tile_index = build_tiles(ground)
    log("minimap (DXT1)...")
    minimap = build_minimap(minimap_rgb)
    metal, metal_cells = metal_grid(spec, mapx // 2, mapy // 2, notes)
    typemap = np.zeros((mapy // 2, mapx // 2), np.uint8)

    smf_rel = spec.get("smf") or f"maps/{spec['file_base']}.smf"
    smt_rel = spec.get("smt") or f"maps/{spec['file_base']}.smt"
    if not smt_rel.startswith("maps/") or "/" in smt_rel[5:]:
        raise CompileError(f"the .smt must sit directly in maps/, got {smt_rel}")
    os.makedirs(os.path.join(archive_dir, "maps"), exist_ok=True)
    mapid = struct.unpack("<i", struct.pack("<I", zlib.crc32(str(spec.get("file_base")).encode("utf-8"))))[0]
    smf_bytes = write_smf(
        os.path.join(archive_dir, smf_rel),
        mapid=mapid,
        mapx=mapx,
        mapy=mapy,
        minh=height["min"],
        maxh=height["max"],
        heights=heights,
        typemap=typemap,
        minimap=minimap,
        metal=metal,
        tile_index=tile_index,
        smt_name=smt_rel[5:],
        num_tiles=len(tiles),
    )
    smt_bytes = write_smt(os.path.join(archive_dir, smt_rel), tiles)

    # quality of the ground texture after DXT1, so a bad encode shows in the report
    sample = ground[: min(tex_h, 1024), : min(tex_w, 1024)]
    sample = sample[: sample.shape[0] // 4 * 4, : sample.shape[1] // 4 * 4]
    mse = float(((dxt1_decode(dxt1(sample)).astype(np.float64) - sample) ** 2).mean())
    psnr = 99.0 if mse == 0 else 10 * np.log10(255**2 / mse)

    report["sections"] = {
        "smf": f"{smf_rel} ({smf_bytes:,} bytes): height {height['min']}..{height['max']}, metal {metal_cells} cells",
        "smt": f"{smt_rel} ({smt_bytes:,} bytes): {len(tiles):,} unique tiles of {tile_index.size:,}",
        "ground": f"{ground_source}; DXT1 {psnr:.1f} dB on the top-left 1024 texels",
        "features": "none in the .smf: placements ship in mapconfig/featureplacer/set.lua",
    }

    if fmt != "none":
        base = spec.get("file_base")
        out_path = os.path.join(export_dir, f"{base}.{fmt}")
        zip_exe = None
        if fmt == "sd7":
            zip_exe = find_seven_zip(seven_zip)
            if not zip_exe:
                notes.append("7-Zip not found: packed as .sdz (zip) instead")
                fmt = "sdz"
                out_path = os.path.join(export_dir, f"{base}.sdz")
        log(f"packing {os.path.basename(out_path)}...")
        pack(archive_dir, out_path, fmt, zip_exe)
        digest = hashlib.sha256(open(out_path, "rb").read()).hexdigest()
        report["archive"] = f"{os.path.basename(out_path)} ({os.path.getsize(out_path):,} bytes, sha256 {digest[:16]})"
    report["files"] = archive_files(archive_dir)
    return report


def format_report(report, ok=True, error=None):
    lines = [f"Map compile: {report.get('name')} ({'OK' if ok else 'FAILED'})", ""]
    if error:
        lines += ["Error:", "  " + error, ""]
    if report.get("archive"):
        lines += ["Archive:", "  " + report["archive"], ""]
    if report.get("sections"):
        lines.append("Written:")
        lines += [f"  {k}: {v}" for k, v in report["sections"].items()]
        lines.append("")
    if report.get("notes"):
        lines.append("Notes:")
        lines += ["  " + n for n in report["notes"]]
        lines.append("")
    if report.get("files"):
        lines.append("Archive files:")
        lines += ["  " + f for f in report["files"]]
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description="Compile a map export folder into a .sd7 map archive.")
    ap.add_argument("export", help="the export folder (holds archive/ and compile/)")
    ap.add_argument("--format", choices=["sd7", "sdz", "none"], default="sd7", help="none: write .smf/.smt only")
    ap.add_argument("--seven-zip", help="path to 7z / 7z.exe")
    args = ap.parse_args(argv)

    report = {"name": os.path.basename(os.path.normpath(args.export))}
    try:
        report = compile_export(args.export, args.format, args.seven_zip)
        ok, error = True, None
    except (CompileError, OSError, KeyError, ValueError) as e:
        ok, error = False, f"{type(e).__name__}: {e}" if not isinstance(e, CompileError) else str(e)
    text = format_report(report, ok, error)
    if os.path.isdir(args.export):
        with open(os.path.join(args.export, "compile_report.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print(text, end="")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
