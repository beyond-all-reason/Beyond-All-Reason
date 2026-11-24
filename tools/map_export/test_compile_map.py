"""Tests for tools/map_export/compile_map.py.  python -m unittest tools/map_export/test_compile_map.py"""

import json
import os
import struct
import sys
import tempfile
import unittest
import zipfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compile_map as mc  # noqa: E402


def smooth_image(h, w, seed=1):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    img = np.stack(
        [
            128 + 100 * np.sin(x / 37 + y / 53),
            128 + 90 * np.cos(x / 23 - y / 41),
            90 + 60 * np.sin((x + y) / 61),
        ],
        axis=-1,
    )
    return np.clip(img + rng.normal(0, 3, img.shape), 0, 255).astype(np.uint8)


def psnr(a, b):
    mse = ((a.astype(np.float64) - b) ** 2).mean()
    return 99.0 if mse == 0 else 10 * np.log10(255**2 / mse)


class Dxt1Test(unittest.TestCase):
    def test_flat_colour_is_exact_in_565(self):
        img = np.zeros((8, 8, 3), np.uint8)
        img[:] = (255, 0, 255)
        out = mc.dxt1_decode(mc.dxt1(img))
        self.assertTrue((out == img).all())

    def test_smooth_image_quality(self):
        img = smooth_image(128, 192)
        self.assertGreater(psnr(mc.dxt1_decode(mc.dxt1(img)), img), 34)

    def test_two_colour_block_keeps_both(self):
        img = np.zeros((4, 4, 3), np.uint8)
        img[:, :2] = (255, 255, 255)
        out = mc.dxt1_decode(mc.dxt1(img))
        self.assertTrue((out == img).all())

    def test_four_colour_mode(self):
        blocks = mc.dxt1(smooth_image(64, 64)).reshape(-1, 8)
        c0 = blocks[:, 0:2].copy().view("<u2")[:, 0]
        c1 = blocks[:, 2:4].copy().view("<u2")[:, 0]
        self.assertTrue((c0 >= c1).all())

    def test_strips_match_whole(self):
        img = smooth_image(64, 32)
        self.assertTrue((mc.dxt1(img, strip_rows=16) == mc.dxt1(img, strip_rows=1024)).all())


class Dxt5Test(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()

    def splat(self, h=64, w=96):
        rgb = smooth_image(h, w)
        a = np.clip(128 + 120 * np.sin(np.mgrid[0:h, 0:w][1] / 19), 0, 255).astype(np.uint8)
        return np.dstack([rgb, a])

    def test_dds_reads_back_with_every_mip(self):
        img = self.splat()
        path = os.path.join(self.tmp.name, "s.dds")
        size, mips = mc.write_dds_dxt5(path, img)
        data = open(path, "rb").read()
        self.assertEqual(len(data), size)
        self.assertEqual(data[84:88], b"DXT5")
        # the full chain: 96x64, 48x32, 24x16, 12x8, 6x4, 3x2, 1x1 (a short one samples as black)
        self.assertEqual((mips, struct.unpack_from("<I", data, 28)[0]), (7, 7))
        self.assertEqual(size, 128 + 16 * (24 * 16 + 12 * 8 + 6 * 4 + 3 * 2 + 2 * 1 + 1 + 1))
        with Image.open(path) as back:
            out = np.asarray(back.convert("RGBA"))
        self.assertGreater(psnr(out[..., :3], img[..., :3]), 30)
        self.assertGreater(psnr(out[..., 3], img[..., 3]), 40)

    def test_flat_alpha_is_exact(self):
        img = self.splat(8, 8)
        img[..., 3] = 200
        path = os.path.join(self.tmp.name, "f.dds")
        mc.write_dds_dxt5(path, img)
        with Image.open(path) as back:
            self.assertTrue((np.asarray(back.convert("RGBA"))[..., 3] == 200).all())


class TilesTest(unittest.TestCase):
    def test_flat_ground_is_one_tile(self):
        img = np.zeros((128, 256, 3), np.uint8)
        img[:] = (110, 130, 90)
        tiles, index = mc.build_tiles(img)
        self.assertEqual(len(tiles), 1)
        self.assertEqual(index.shape, (4, 8))
        self.assertTrue((index == 0).all())
        self.assertEqual(tiles.shape[1], mc.TILE_BYTES)

    def test_tiles_decode_back(self):
        img = smooth_image(64, 96)
        tiles, index = mc.build_tiles(img)
        # level 0 of tile (row 1, col 2) decodes to that 32x32 patch
        t = tiles[index[1, 2]][:512].reshape(8, 8, 8)
        self.assertGreater(psnr(mc.dxt1_decode(t), img[32:64, 64:96]), 30)

    def test_index_order_is_first_seen(self):
        img = np.zeros((32, 96, 3), np.uint8)
        img[:, 32:64] = 200
        tiles, index = mc.build_tiles(img)
        self.assertEqual(index.tolist(), [[0, 1, 0]])

    def test_minimap_size(self):
        self.assertEqual(len(mc.build_minimap(smooth_image(100, 80))), mc.MINIMAP_BYTES)


def write_export(root, size_x=1, size_z=2, squares=True, metal=True):
    comp = os.path.join(root, "compile")
    arch = os.path.join(root, "archive")
    os.makedirs(os.path.join(comp, "diffuse"))
    os.makedirs(os.path.join(arch, "mapconfig"))
    with open(os.path.join(arch, "mapinfo.lua"), "w") as f:
        f.write('return { name = "Tiny", version = "1.0", mapfile = "maps/tiny_1_0.smf" }\n')
    with open(os.path.join(arch, "mapconfig", "lights.lua"), "w") as f:
        f.write("return { version = 1, lights = {} }\n")
    w, h = size_x * 64 + 1, size_z * 64 + 1
    hm = (np.arange(w * h).reshape(h, w) % 65536).astype(np.uint16)
    Image.fromarray(hm).save(os.path.join(comp, "heightmap.png"))
    Image.fromarray(smooth_image(64, 32)).save(os.path.join(comp, "minimap.png"))
    spec = {
        "format_version": mc.FORMAT_VERSION,
        "name": "Tiny 1.0",
        "file_base": "tiny_1_0",
        "smf": "maps/tiny_1_0.smf",
        "smt": "maps/tiny_1_0.smt",
        "size_x": size_x,
        "size_z": size_z,
        "square_size": 8,
        "height": {"min": -50, "max": 300},
        "heightmap": "heightmap.png",
        "minimap": "minimap.png",
        "diffuse": {"base_color": [10, 20, 30]},
    }
    if squares:
        Image.fromarray(np.full((256, 256, 3), 77, np.uint8)).save(os.path.join(comp, "diffuse", "sq_0_1.png"))
        spec["diffuse"].update({"square_size": 256, "squares": [[0, 1]]})
    if metal:
        spec["metal"] = {"max_metal": 2.0, "square_size": 16, "width": 32, "height": 64, "cells": [[3, 5, 255], [31, 63, 128]]}
    with open(os.path.join(comp, "compile.json"), "w") as f:
        json.dump(spec, f)
    return hm


class CompileTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_smf_layout(self):
        hm = write_export(self.root)
        report = mc.compile_export(self.root, fmt="none", log=lambda *_: None)
        smf = os.path.join(self.root, "archive", "maps", "tiny_1_0.smf")
        data = open(smf, "rb").read()
        h = mc.read_smf_header(smf)
        magic, version, _, mapx, mapy, sq, tps, tile, minh, maxh = h[:10]
        hptr, tptr, tilesptr, mmptr, metalptr, featptr, extra = h[10:]
        self.assertEqual(magic, b"spring map file\0")
        self.assertEqual((version, mapx, mapy, sq, tps, tile), (1, 64, 128, 8, 8, 32))
        self.assertEqual((minh, maxh), (-50.0, 300.0))
        self.assertEqual(extra, 0)
        heights = np.frombuffer(data, "<u2", count=65 * 129, offset=hptr).reshape(129, 65)
        self.assertTrue((heights == hm).all())
        self.assertEqual(tptr, hptr + 65 * 129 * 2)
        nfiles, ntiles, n1 = struct.unpack_from("<iii", data, tilesptr)
        self.assertEqual(nfiles, 1)
        self.assertEqual(ntiles, n1)
        name_end = data.index(b"\0", tilesptr + 12)
        self.assertEqual(data[tilesptr + 12 : name_end], b"tiny_1_0.smt")
        index = np.frombuffer(data, "<i4", count=16 * 32, offset=name_end + 1)
        self.assertEqual(int(index.max()) + 1, ntiles)
        self.assertEqual(mmptr, name_end + 1 + 16 * 32 * 4)
        self.assertEqual(metalptr, mmptr + mc.MINIMAP_BYTES)
        metal = np.frombuffer(data, np.uint8, count=32 * 64, offset=metalptr).reshape(64, 32)
        self.assertEqual((metal[5, 3], metal[63, 31], int(metal.sum())), (255, 128, 383))
        self.assertEqual(struct.unpack_from("<ii", data, featptr), (0, 0))
        self.assertEqual(len(data), featptr + 8)

        smt = open(os.path.join(self.root, "archive", "maps", "tiny_1_0.smt"), "rb").read()
        magic, version, n, tsize, comp = mc.TILE_FILE_HEADER.unpack_from(smt)
        self.assertEqual((magic, version, n, tsize, comp), (b"spring tilefile\0", 1, ntiles, 32, 1))
        self.assertEqual(len(smt), 32 + ntiles * mc.TILE_BYTES)
        self.assertIn("metal 2 cells", report["sections"]["smf"])

    def test_square_lands_where_named(self):
        write_export(self.root)
        mc.compile_export(self.root, fmt="none", log=lambda *_: None)
        smf = os.path.join(self.root, "archive", "maps", "tiny_1_0.smf")
        data = open(smf, "rb").read()
        tilesptr = mc.read_smf_header(smf)[12]
        name_end = data.index(b"\0", tilesptr + 12)
        index = np.frombuffer(data, "<i4", count=16 * 32, offset=name_end + 1).reshape(32, 16)
        smt = open(os.path.join(self.root, "archive", "maps", "tiny_1_0.smt"), "rb").read()
        tile = np.frombuffer(smt, np.uint8, count=512, offset=32 + int(index[10, 3]) * mc.TILE_BYTES)
        # square 0,1 of 256 texels covers rows 256..511: tile row 10 is inside it, flat grey 77 (74 in 565)
        out = mc.dxt1_decode(tile.reshape(8, 8, 8)).astype(int)
        self.assertLessEqual(int(np.abs(out - 77).max()), 4)  # one RGB565 step

    def test_deterministic(self):
        write_export(self.root)
        mc.compile_export(self.root, fmt="sdz", log=lambda *_: None)
        a = open(os.path.join(self.root, "tiny_1_0.sdz"), "rb").read()
        mc.compile_export(self.root, fmt="sdz", log=lambda *_: None)
        b = open(os.path.join(self.root, "tiny_1_0.sdz"), "rb").read()
        self.assertEqual(a, b)

    def test_sdz_contents(self):
        write_export(self.root, squares=False, metal=False)
        report = mc.compile_export(self.root, fmt="sdz", log=lambda *_: None)
        with zipfile.ZipFile(os.path.join(self.root, "tiny_1_0.sdz")) as z:
            names = sorted(z.namelist())
        self.assertEqual(
            names, ["mapconfig/lights.lua", "mapinfo.lua", "maps/tiny_1_0.smf", "maps/tiny_1_0.smt"]
        )
        self.assertIn("minimap stretched", report["sections"]["ground"])

    def test_sd7_with_seven_zip(self):
        exe = mc.find_seven_zip(None)
        if not exe:
            self.skipTest("no 7-Zip")
        write_export(self.root)
        report = mc.compile_export(self.root, fmt="sd7", log=lambda *_: None)
        self.assertTrue(os.path.isfile(os.path.join(self.root, "tiny_1_0.sd7")))
        self.assertIn("tiny_1_0.sd7", report["archive"])

    def test_splat_ships_as_dxt5(self):
        write_export(self.root)
        splat = np.zeros((128, 64, 4), np.uint8)
        splat[:64, :, 0] = 255  # top half on channel 1
        splat[64:, :, 3] = 255
        Image.fromarray(splat).save(os.path.join(self.root, "compile", "splat.png"))
        p = os.path.join(self.root, "compile", "compile.json")
        spec = json.load(open(p))
        spec["splat"] = {"src": "splat.png", "dds": "maps/tiny_1_0_splat.dds"}
        json.dump(spec, open(p, "w"))
        report = mc.compile_export(self.root, fmt="none", log=lambda *_: None)
        self.assertIn("DXT5", report["sections"]["splat"])
        self.assertIn("maps/tiny_1_0_splat.dds", report["files"])
        # stored bottom row first, as the engine expects a DDS
        with Image.open(os.path.join(self.root, "archive", "maps", "tiny_1_0_splat.dds")) as back:
            out = np.asarray(back.convert("RGBA"))
        self.assertTrue((out == splat[::-1]).all())

    def test_wrong_heightmap_size_is_resized(self):
        write_export(self.root)
        Image.fromarray(np.zeros((40, 30), np.uint16)).save(os.path.join(self.root, "compile", "heightmap.png"))
        report = mc.compile_export(self.root, fmt="none", log=lambda *_: None)
        self.assertTrue(any("resized to 65x129" in n for n in report["notes"]))

    def test_errors(self):
        with self.assertRaises(mc.CompileError):
            mc.compile_export(self.root, fmt="none", log=lambda *_: None)
        write_export(self.root)
        p = os.path.join(self.root, "compile", "compile.json")
        spec = json.load(open(p))
        spec["format_version"] = 99
        json.dump(spec, open(p, "w"))
        with self.assertRaises(mc.CompileError):
            mc.compile_export(self.root, fmt="none", log=lambda *_: None)

    def test_cli_writes_report(self):
        write_export(self.root)
        self.assertEqual(mc.main([self.root, "--format", "none"]), 0)
        text = open(os.path.join(self.root, "compile_report.txt")).read()
        self.assertIn("(OK)", text)
        self.assertEqual(mc.main([os.path.join(self.root, "nope")]), 1)


if __name__ == "__main__":
    unittest.main()
