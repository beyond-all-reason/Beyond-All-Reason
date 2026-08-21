#!/usr/bin/env python3
"""Bake uniformly scaled copies of Spring/Recoil .s3o models.

The engine currently exposes no way to scale a feature at runtime --
Spring.SetFeaturePieceMatrix validates the matrix with IsRotOrRotTranMatrix()
and rejects anything carrying scale, and LocalModelPiece::SetScaling is
reachable only from unit animation scripts. Until a real callout exists, the
Feature Placer's scale variation works by snapping rolled scales to pre-baked
model variants, and this script is what bakes them.

Scaling an s3o is exact and lossless: multiply the header radius / height /
midpos, every piece's parent-relative offset, and every vertex position by the
factor. Normals, UVs, indices, strings, and the piece tree are untouched, so
the output differs from the input only in those floats.

Usage:
    python tools/s3o_scale.py objects3d/fir_tree_large.s3o 0.55
        -> objects3d/fir_tree_large_s055.s3o
    python tools/s3o_scale.py <file.s3o> <factor> [out.s3o]

The _sNNN suffix is factor*100, zero-padded, matching the variant featuredefs
in features/enginetrees_override.lua.
"""

import struct
import sys

HEADER = struct.Struct("<12si2f3f4i")  # magic, version, radius, height, mid*3, rootPiece, collisionData, tex1, tex2
PIECE = struct.Struct("<10i3f")  # name, numchildren, children, numVertices, vertices, vertexType, primitiveType, vertexTableSize, vertexTable, collisionData, offset*3
VERTEX_SIZE = 32  # pos*3f, normal*3f, uv*2f
MAGIC = b"Spring unit\x00"


def scale_s3o(data: bytearray, factor: float) -> bytearray:
    magic, version, radius, height, midx, midy, midz, root_piece, coll, tex1, tex2 = HEADER.unpack_from(data, 0)
    if magic != MAGIC:
        raise ValueError(f"not an s3o file (magic {magic!r})")
    if version != 0:
        raise ValueError(f"unsupported s3o version {version}")

    out = bytearray(data)
    HEADER.pack_into(
        out, 0, magic, version, radius * factor, height * factor, midx * factor, midy * factor, midz * factor,
        root_piece, coll, tex1, tex2,
    )

    seen = set()

    def walk(piece_ofs: int):
        if piece_ofs in seen:  # corrupt files could loop; do not
            raise ValueError(f"piece cycle at offset {piece_ofs}")
        seen.add(piece_ofs)

        (name, numchildren, children, num_vertices, vertices, vertex_type, primitive_type,
         vertex_table_size, vertex_table, coll_data, ox, oy, oz) = PIECE.unpack_from(data, piece_ofs)

        PIECE.pack_into(
            out, piece_ofs, name, numchildren, children, num_vertices, vertices, vertex_type,
            primitive_type, vertex_table_size, vertex_table, coll_data,
            ox * factor, oy * factor, oz * factor,
        )

        for v in range(num_vertices):
            vofs = vertices + v * VERTEX_SIZE
            x, y, z = struct.unpack_from("<3f", data, vofs)
            struct.pack_into("<3f", out, vofs, x * factor, y * factor, z * factor)

        for c in range(numchildren):
            (child_ofs,) = struct.unpack_from("<i", data, children + c * 4)
            walk(child_ofs)

    walk(root_piece)
    return out


def describe(data: bytes) -> str:
    _, _, radius, height, midx, midy, midz, root, *_ = HEADER.unpack_from(data, 0)
    pieces, verts = 0, 0

    def walk(piece_ofs):
        nonlocal pieces, verts
        p = PIECE.unpack_from(data, piece_ofs)
        pieces += 1
        verts += p[3]
        for c in range(p[1]):
            (child,) = struct.unpack_from("<i", data, p[2] + c * 4)
            walk(child)

    walk(root)
    return f"radius {radius:.1f} height {height:.1f} mid ({midx:.1f} {midy:.1f} {midz:.1f}) pieces {pieces} verts {verts}"


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    src = sys.argv[1]
    factor = float(sys.argv[2])
    if not (0.01 <= factor <= 100):
        raise SystemExit(f"factor {factor} out of sanity range")
    dst = sys.argv[3] if len(sys.argv) > 3 else src[:-4] + f"_s{round(factor * 100):03d}.s3o"

    with open(src, "rb") as f:
        data = bytearray(f.read())
    print(f"{src}: {describe(data)}")
    out = scale_s3o(data, factor)
    with open(dst, "wb") as f:
        f.write(out)
    print(f"{dst}: {describe(out)}")


if __name__ == "__main__":
    main()
