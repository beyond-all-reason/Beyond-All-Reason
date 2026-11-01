# SPDX-License-Identifier: GPL-2.0-or-later
import unittest
from income_settings import team_income_multipliers


class IncomeSettingsTests(unittest.TestCase):
    def test_different_advantages_keep_opening_opponents_at_normal_income(self):
        teams = [{"region": r} for r in ["grass", "grass", "sand", "sand", "snow", "snow", "lava", "lava"]]
        self.assertEqual(team_income_multipliers(teams, per_region="2,4,8,16"),
                         {0: 2, 1: 1, 2: 4, 3: 1, 4: 8, 5: 1, 6: 16, 7: 1})

    def test_uniform_mode_and_arbitrary_authored_region_order(self):
        teams = [{"region": r} for r in [9, 2, 9, 2]]
        self.assertEqual(team_income_multipliers(teams, uniform=10), {0: 10, 1: 10, 2: 1, 3: 1})
        self.assertEqual(team_income_multipliers(teams, per_region="2,16"), {0: 2, 1: 16, 2: 1, 3: 1})

    def test_invalid_factors_and_wrong_region_count_fail(self):
        for value in ["2,4", "nan", "inf", "0", "0.5", "-1", "words", "2,"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                team_income_multipliers([{"region": 1}], per_region=value)


if __name__ == "__main__":
    unittest.main()
