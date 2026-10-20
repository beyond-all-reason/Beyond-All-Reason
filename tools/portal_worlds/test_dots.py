#!/usr/bin/env python3
"""Schema and spatial-review regressions; no engine or browser required."""

import copy
import gzip
import json
from pathlib import Path
import tempfile
import unittest

import dots


class RecordingTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name) / "capture.jsonl"
        self.header = {
            "type": "header",
            "format": "portal-dots",
            "version": 1,
            "game": "fixture",
            "map": "fixture",
            "fps": 30,
            "regions": [
                dict(x0=0, z0=0, x1=100, z1=100),
                dict(x0=132, z0=0, x1=232, z1=100),
            ],
            "unit_defs": {"1": dict(speed=100, builder=False)},
            "columns": {"units": list(range(16)), "projectiles": list(range(9))},
        }
        self.unit = [7, 1, 0, 50, 0, 50, 100, 100, 1, 10, 8, 75, 0, 75, 1, 0]

    def check_rows(self, rows):
        footer = dict(
            type="end",
            frame=30,
            reason="fixture",
            winners=[],
            samples=sum(r["type"] == "sample" for r in rows),
            events=sum(r["type"] == "event" for r in rows),
        )
        self.path.write_text(
            "\n".join(json.dumps(r) for r in [self.header, *rows, footer]) + "\n"
        )
        return dots.review(self.path)

    def sample(self, frame=15):
        return dict(
            type="sample", frame=frame, units=[copy.copy(self.unit)], projectiles=[]
        )

    def test_legitimate_foreign_goal_is_not_barrier_goal(self):
        sample = self.sample()
        sample["units"][0][11:14] = [180, 0, 50]
        self.assertNotIn("gap_goal_samples", self.check_rows([sample])["counts"])

    def test_goal_in_cubicle_barrier_is_reported(self):
        sample = self.sample()
        sample["units"][0][11:14] = [115, 0, 50]
        self.assertEqual(self.check_rows([sample])["counts"]["gap_goal_samples"], 1)

    def test_attack_unit_id_is_not_position(self):
        sample = self.sample()
        sample["units"][0][9:14] = [20, 8, 115, False, False]
        self.assertNotIn("gap_goal_samples", self.check_rows([sample])["counts"])

    def test_projectile_provenance_differs_from_current_owner_position(self):
        hit = dict(
            type="event",
            frame=16,
            kind="damage",
            data=dict(source=1, region=2, source_kind="projectile"),
        )
        result = self.check_rows([self.sample(), hit])
        self.assertEqual(len(result["findings"]["foreign_damage"]), 1)
        hit["data"]["source_kind"] = "attacker-position"
        result = self.check_rows([self.sample(), hit])
        self.assertNotIn("foreign_damage", result["findings"])
        self.assertEqual(len(result["findings"]["damage_position_candidates"]), 1)

    def test_projectile_crossing_is_reported(self):
        sample = self.sample()
        sample["projectiles"] = [[9, 1, 7, 0, 180, 10, 50, 1, 2]]
        self.assertEqual(
            self.check_rows([sample])["counts"]["foreign_projectile_samples"], 1
        )

    def test_missing_footer_is_rejected(self):
        self.path.write_text(
            json.dumps(self.header) + "\n" + json.dumps(self.sample()) + "\n"
        )
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            dots.review(self.path)

    def test_duplicate_frame_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "non-increasing"):
            self.check_rows([self.sample(), self.sample()])

    def test_position_region_mismatch_is_rejected(self):
        sample = self.sample()
        sample["units"][0][14] = 2
        with self.assertRaisesRegex(ValueError, "disagrees"):
            self.check_rows([sample])

    def test_integral_float_ids_are_accepted(self):
        sample = self.sample()
        sample["units"][0] = [float(v) if type(v) is int else v for v in self.unit]
        self.assertEqual(self.check_rows([sample])["counts"]["samples"], 1)

    def test_display_copy_keeps_world_membership_at_rounded_edge(self):
        sample = self.sample(frame=30)
        sample["units"][0][3] = 99.98
        self.check_rows([sample])
        data = [
            json.loads(line)
            for line in gzip.decompress(dots.presentation_copy(self.path, 30))
            .decode()
            .splitlines()
        ]
        self.assertEqual(data[1]["units"][0][3], 99.98)
        self.assertEqual(data[-1]["samples"], 1)
        self.assertEqual(
            data[0]["presentation"]["source_sha256"], dots.digest(self.path)
        )

    def test_display_copy_keeps_a_final_partial_sample(self):
        self.check_rows([self.sample(frame=15)])
        data = [
            json.loads(line)
            for line in gzip.decompress(dots.presentation_copy(self.path, 30))
            .decode()
            .splitlines()
        ]
        self.assertEqual(data[-2]["frame"], 15)
        self.assertEqual(data[-1]["samples"], 1)

    def test_footer_cannot_predate_a_sample(self):
        with self.assertRaisesRegex(ValueError, "predates"):
            self.check_rows([self.sample(frame=45)])

    def test_nonfinite_json_is_rejected(self):
        sample = self.sample()
        sample["units"][0][3] = float("nan")
        with self.assertRaisesRegex(ValueError, "Non-finite"):
            self.check_rows([sample])


if __name__ == "__main__":
    unittest.main()
