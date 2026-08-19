# Attack target-list reproduction scenario

This branch contains the exact small-unit setup recorded for
[Beyond-All-Reason issue #8793](https://github.com/beyond-all-reason/Beyond-All-Reason/issues/8793).

It requires a Recoil Engine build containing
[`CMD_ATTACK_TARGETS` from RecoilEngine PR #3237](https://github.com/beyond-all-reason/RecoilEngine/pull/3237)
and the map `All That Glitters v2.2.3`.

The scenario creates five player-controlled Sheldons at the positions captured
from save `20260819_214357`, opposed by four Fatboys and ten Ticks. All scenario
units start on Hold Fire and Hold Position. The ordinary commanders remain far
outside the camera view so BAR's commander-death rule does not end the match.
The camera is restored to the captured position and the five Sheldons are
selected automatically.

Run it from a BAR data directory in which this checkout is linked as the active
game:

```sh
'/path/to/recoil/install/spring' \
  --window \
  --isolation \
  --write-dir '/path/to/bar-data' \
  tools/StartScripts/startscript_attack_target_list_scenario.txt
```

The startscript enables the scenario with:

```text
attacktargetlistscenario=1;
```

It also exposes the engine modrule used by the comparison:

```text
attacktargetlistpreferlistedtargets=1;
```

- `1`: while executing `CMD_ATTACK_TARGETS`, opportunity-fire targets are
  restricted to units in the supplied target list. The ordered current target
  remains the movement goal. This makes Attack's firing behavior match Set
  Target more closely.
- `0`: the unit may opportunity-fire at any valid enemy while moving toward the
  ordered current list target. This preserves ordinary Attack behavior.

Change only this value and restart the scenario to compare both behaviors under
identical positions, unit states, camera, and selection.
