# SPDX-License-Identifier: GPL-2.0-or-later
"""Income settings for resource-asymmetric AI demonstrations."""
import math


def team_income_multipliers(teams, uniform=1, per_region=None):
    """Give the first team in each authored region its configured income factor."""
    first = {}
    for team, entry in enumerate(teams):
        first.setdefault(entry["region"], team)
    regions = list(first)
    values = [float(value) for value in per_region.split(",")] if per_region is not None else [uniform] * len(regions)
    if len(values) != len(regions):
        raise ValueError("Provide one income multiplier per authored region (" + str(len(regions)) + ")")
    if any(not math.isfinite(value) or value < 1 for value in values):
        raise ValueError("Income multipliers must be finite and at least 1")
    factors = dict(zip(regions, values))
    return {team: factors[entry["region"]] if first[entry["region"]] == team else 1
            for team, entry in enumerate(teams)}
