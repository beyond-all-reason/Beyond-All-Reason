#!/usr/bin/env python3
"""Merge several .s3o models into one multi-piece clump model.

Why: featuredefs and models are fixed at game start, so a clump of placed trees
cannot be fused at runtime. Baking clumps offline gives the same result the
merge would: ONE feature entity per clump (one sim object, one cull/drawFlag
walk, one quadfield entry) while the engine's instanced model drawer batches
all clumps of the same def exactly like it batches single trees.

Each source tree becomes its own piece in the merged model:
  - per-tree uniform scale and Y-rotation are baked into the piece's vertices
    (s3o pieces carry only an offset, no rotation/scale),
  - the piece offset is the tree's position inside the clump,
  - vertex/index arrays are copied per piece, so no index rewriting happens.
Keeping one piece per tree preserves the option of per-piece collision volumes
and Spring.SetFeaturePieceVisible tricks later.

All sources must share the same texture pair (asserted).

Usage:
    python tools/s3o_merge.py --palette
        Bake the standard fir clump palette into objects3d/ and write
        features/tree_clumps.lua. Deterministic: same output every run.

    python tools/s3o_merge.py out.s3o spec.py
        Custom merge; spec.py must define ENTRIES = [ (file, x, z, yawDeg,
        scale, y), ... ] with positions relative to the clump origin.
"""

import math
import os
import random
import struct
import sys

HEADER = struct.Struct("<12si2f3f4i")
PIECE = struct.Struct("<10i3f")
VERTEX = struct.Struct("<8f")
MAGIC = b"Spring unit\x00"


def read_cstr(data: bytes, ofs: int) -> str:
    return data[ofs:data.index(b"\x00", ofs)].decode()


def load_source(path):
    """Flatten an s3o into (vertices, indices, tex1, tex2).

    Pieces only carry offsets, so flattening child geometry into parent space
    is exact: add the cumulative offset to each vertex position.
    """
    with open(path, "rb") as f:
        data = f.read()
    magic, version, radius, height, mx, my, mz, root, coll, t1, t2 = HEADER.unpack_from(data, 0)
    if magic != MAGIC or version != 0:
        raise ValueError(f"{path}: not an s3o v0 file")

    verts, indices = [], []

    def walk(piece_ofs, base):
        (name, nch, children, nverts, vofs, vtype, ptype, tsize, tofs, cdata, ox, oy, oz) = PIECE.unpack_from(
            data, piece_ofs
        )
        if ptype != 0 and nverts > 0:
            raise ValueError(f"{path}: piece {read_cstr(data, name)} has primitiveType {ptype}, only 0 (triangles) supported")
        bx, by, bz = base[0] + ox, base[1] + oy, base[2] + oz
        first = len(verts)
        for v in range(nverts):
            x, y, z, nx, ny, nz, u, tv = VERTEX.unpack_from(data, vofs + v * VERTEX.size)
            verts.append((x + bx, y + by, z + bz, nx, ny, nz, u, tv))
        for i in range(tsize):
            (idx,) = struct.unpack_from("<i", data, tofs + i * 4)
            indices.append(first + idx)
        for c in range(nch):
            (child,) = struct.unpack_from("<i", data, children + c * 4)
            walk(child, (bx, by, bz))

    walk(root, (0.0, 0.0, 0.0))
    return verts, indices, read_cstr(data, t1), read_cstr(data, t2) if t2 else ""


def merge(entries):
    """entries: list of (s3oPath, x, z, yawDeg, scale, y). Returns (bytes, stats)."""
    trees = []
    tex1 = tex2 = None
    for path, x, z, yaw_deg, scale, y in entries:
        verts, indices, t1, t2 = load_source(path)
        if tex1 is None:
            tex1, tex2 = t1, t2
        elif (t1, t2) != (tex1, tex2):
            raise ValueError(f"{path}: texture pair ({t1},{t2}) differs from ({tex1},{tex2})")
        c, s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
        out = []
        for vx, vy, vz, nx, ny, nz, u, tv in verts:
            vx, vy, vz = vx * scale, vy * scale, vz * scale
            rx, rz = vx * c + vz * s, -vx * s + vz * c
            rnx, rnz = nx * c + nz * s, -nx * s + nz * c
            out.append((rx, vy, rz, rnx, ny, rnz, u, tv))
        trees.append({"verts": out, "indices": indices, "pos": (x, y, z)})

    # Bounds over piece-offset vertices, for header radius/height/midpos.
    max_y = 0.0
    for t in trees:
        py = t["pos"][1]
        for v in t["verts"]:
            max_y = max(max_y, v[1] + py)
    mid = (0.0, max_y * 0.5, 0.0)
    max_r2 = 0.0
    for t in trees:
        px, py, pz = t["pos"]
        for vx, vy, vz, *_ in t["verts"]:
            max_r2 = max(max_r2, (vx + px) ** 2 + (vy + py - mid[1]) ** 2 + (vz + pz) ** 2)
    radius = math.sqrt(max_r2)

    # Layout: header | root piece | root name | children table |
    #         per tree (piece | name | verts | indices) | tex strings
    blob = bytearray(HEADER.size)
    root_ofs = len(blob)
    blob += bytes(PIECE.size)
    root_name_ofs = len(blob)
    blob += b"clump_root\x00"
    children_ofs = len(blob)
    blob += bytes(4 * len(trees))

    piece_ofss = []
    for i, t in enumerate(trees):
        piece_ofs = len(blob)
        piece_ofss.append(piece_ofs)
        blob += bytes(PIECE.size)
        name_ofs = len(blob)
        blob += f"tree{i}\x00".encode()
        verts_ofs = len(blob)
        for v in t["verts"]:
            blob += VERTEX.pack(*v)
        table_ofs = len(blob)
        for idx in t["indices"]:
            blob += struct.pack("<i", idx)
        px, py, pz = t["pos"]
        PIECE.pack_into(
            blob, piece_ofs, name_ofs, 0, 0, len(t["verts"]), verts_ofs, 0, 0,
            len(t["indices"]), table_ofs, 0, px, py, pz,
        )

    tex1_ofs = len(blob)
    blob += tex1.encode() + b"\x00"
    tex2_ofs = len(blob)
    blob += tex2.encode() + b"\x00"

    for i, ofs in enumerate(piece_ofss):
        struct.pack_into("<i", blob, children_ofs + i * 4, ofs)
    PIECE.pack_into(blob, root_ofs, root_name_ofs, len(trees), children_ofs, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0)
    HEADER.pack_into(blob, 0, MAGIC, 0, radius, max_y, *mid, root_ofs, 0, tex1_ofs, tex2_ofs)

    stats = {
        "trees": len(trees),
        "verts": sum(len(t["verts"]) for t in trees),
        "height": max_y,
        "radius": radius,
    }
    return bytes(blob), stats


# ---------------------------------------------------------------------------
# Palette: the standard fir clumps + their featuredefs
# ---------------------------------------------------------------------------

MODELS = [
    ("objects3d/fir_tree_smallest.s3o", 72.0),
    ("objects3d/fir_tree_small.s3o", 100.0),
    ("objects3d/fir_tree_medium.s3o", 90.0),
    ("objects3d/fir_tree_large.s3o", 90.0),
]

# (suffix, treeCount, clumpRadius, footprint, seed)
ARCHETYPES = [
    ("s1", 3, 45, 2, 101),
    ("s2", 3, 45, 2, 202),
    ("m1", 5, 70, 3, 303),
    ("m2", 5, 70, 3, 404),
    ("l1", 8, 100, 4, 505),
    ("l2", 8, 100, 4, 606),
]

SCALE_LO, SCALE_HI = 0.40, 0.90


def gen_clump(count, clump_radius, seed):
    """Clustered layout mirroring the in-game brush: min spacing scales with
    tree size, bigger trees toward the core, positions centred on the origin."""
    rng = random.Random(seed)
    placed = []  # (x, z, scale)
    tries = 0
    while len(placed) < count and tries < count * 200:
        tries += 1
        ang = rng.random() * math.tau
        # sqrt-free radial bias: keeps the core denser than uniform-disk
        dist = clump_radius * rng.random() ** 0.7
        x, z = dist * math.cos(ang), dist * math.sin(ang)
        closeness = 1.0 - dist / clump_radius
        t = min(1.0, max(0.0, closeness + (rng.random() - 0.5) * 0.4))
        scale = SCALE_LO + (SCALE_HI - SCALE_LO) * t
        if all((x - px) ** 2 + (z - pz) ** 2 >= (18.0 * 0.5 * (scale + ps)) ** 2 for px, pz, ps in placed):
            placed.append((x, z, scale))
    # Centre on the visual centroid so the feature origin sits mid-clump.
    cx = sum(p[0] for p in placed) / len(placed)
    cz = sum(p[1] for p in placed) / len(placed)
    entries = []
    for x, z, scale in placed:
        model = MODELS[rng.randrange(len(MODELS))][0]
        entries.append((model, x - cx, z - cz, rng.random() * 360.0, scale, 0.0))
    return entries


# Whole-clump size variants, baked by feeding the merged model through
# tools/s3o_scale.py's transform. Same factor ladder as the single-tree
# variants, so the placer's Scale Min/Max sliders snap clumps the same way.
VARIANT_FACTORS = [0.40, 0.55, 0.70, 0.85, 1.15]


def make_def(name, obj, trees, total_scale, footprint, col_d, col_h, factor=None):
    f = factor or 1.0
    lines = [
        f"\t{name} = {{",
        f"\t\tdescription = [[Tree Clump ({trees} trees)]],",
        "\t\tblocking = true,",
        "\t\tburnable = true,",
        "\t\treclaimable = true,",
        f"\t\tenergy = {round(250 * total_scale * f)},",
        f"\t\tdamage = {round(250 * total_scale * f)},",
        "\t\tmetal = 0,",
        f"\t\treclaimTime = {round(1500 * total_scale * f)},",
        f"\t\tmass = {max(1, round(20 * total_scale * f))},",
        "\t\tupright = true,",
        f'\t\tobject = "{obj}",',
        f"\t\tfootprintX = {max(1, round(footprint * f))},",
        f"\t\tfootprintZ = {max(1, round(footprint * f))},",
        f"\t\tcollisionVolumeScales = [[{round(col_d * f)} {round(col_h * f)} {round(col_d * f)}]],",
        "\t\tcollisionVolumeType = [[cylY]],",
        "",
        "\t\tcustomParams = {",
        '\t\t\tmodel_author = "Beherith, 0 A.D. (merged by tools/s3o_merge.py)",',
        '\t\t\tnormalmaps = "yes",',
        '\t\t\tnormaltex = "unittextures/tree_fir_tall_5_normal.dds",',
        '\t\t\ttreeshader = "yes",',
        '\t\t\trandomrotate = "true",',
        '\t\t\tcategory = "Plants",',
        '\t\t\tset = "0AD features",',
        f'\t\t\tclump_trees = "{trees}",',
    ]
    if factor:
        base = name.rsplit("_s", 1)[0]
        lines += [
            f'\t\t\tscale_base = "{base}",',
            f'\t\t\tscale_factor = "{factor}",',
        ]
    lines += ["\t\t},", "\t},", ""]
    return "\n".join(lines)


def bake_palette():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from s3o_scale import scale_s3o

    defs = []
    for suffix, count, clump_radius, footprint, seed in ARCHETYPES:
        entries = gen_clump(count, clump_radius, seed)
        blob, stats = merge(entries)
        name = f"treecluster_fir_{suffix}"
        out = f"objects3d/{name}.s3o"
        with open(out, "wb") as f:
            f.write(blob)
        total_scale = sum(e[4] for e in entries)
        col_d = int(clump_radius * 1.4)
        col_h = int(stats["height"])
        defs.append(make_def(name, f"{name}.s3o", stats["trees"], total_scale, footprint, col_d, col_h))
        print(f"{out}: {stats['trees']} trees, {stats['verts']} verts, height {stats['height']:.0f}, radius {stats['radius']:.0f}")

        for factor in VARIANT_FACTORS:
            vname = f"{name}_s{round(factor * 100):03d}"
            with open(f"objects3d/{vname}.s3o", "wb") as f:
                f.write(scale_s3o(bytearray(blob), factor))
            defs.append(make_def(vname, f"{vname}.s3o", stats["trees"], total_scale, footprint, col_d, col_h, factor))

    lua = (
        "-- Generated by `python tools/s3o_merge.py --palette` -- DO NOT HAND-EDIT.\n"
        "--\n"
        "-- Pre-baked fir clumps: one FEATURE per clump of trees, so a forest costs\n"
        "-- a fraction of the entities (sim objects, culling, quadfield) while the\n"
        "-- engine's instanced drawer batches clumps of the same def exactly like\n"
        "-- single trees. Wood value, mass, and collision track the summed trees.\n"
        "-- The engine cannot merge features at runtime (defs and models are fixed\n"
        "-- at game start), which is why these exist. See tools/s3o_merge.py.\n"
        "local clumpDefs = {\n" + "".join(defs) + "}\n\nreturn lowerkeys(clumpDefs)\n"
    )
    with open("features/tree_clumps.lua", "w", newline="\n") as f:
        f.write(lua)
    print(f"features/tree_clumps.lua: {len(defs)} clump defs")


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "--palette":
        bake_palette()
        return
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    out = sys.argv[1]
    spec = {}
    with open(sys.argv[2]) as f:
        exec(f.read(), spec)
    blob, stats = merge(spec["ENTRIES"])
    with open(out, "wb") as f:
        f.write(blob)
    print(f"{out}: {stats}")


if __name__ == "__main__":
    main()
