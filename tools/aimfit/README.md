# aimfit: measuring `aimFromEstimate` values

Before a weapon has aimed, the engine tests line of fire from the `AimFromWeapon`
piece (or, for missile launchers, the current muzzle). The real shot is tested from
the muzzle after the turret has turned. Where those two positions differ the unit
either aims and then never fires, or drops a target it could have hit. The engine's
`aimFromEstimate` weapon tag replaces the pre-aim position with a prediction of
where the muzzle will be once the script has aimed:

```lua
weapons = {
	[1] = {
		def = "CORWOLV_GUN",
		aimFromEstimate = { pivotX, pivotY, pivotZ, lateral, forward, barrelForward, barrelUp },
	},
},
```

in unit space: the yaw pivot, an offset that turns with yaw only, and a barrel offset
that turns with yaw and pitch. `gamedata/aim_from_estimates.lua` holds generated
values for the roster and `gamedata/unitdefs_post.lua` applies them; a value written
in a unit file wins, and `tweakunits` can override both.

## Regenerating

1. Run the roster gadget headless. It spawns every unit with a ground-attack weapon
   on `Comet Catcher Remake 1.8`, aims each weapon slot at 48 targets, records the
   real muzzle position of every shot, fits the seven parameters and reports the
   out-of-sample error against the current `AimFromWeapon` behaviour:

   ```sh
   spring-headless --isolation --write-dir /path/to/isolated-data \
     tools/StartScripts/startscript_aimfit_roster.txt
   grep AIMFIT /path/to/isolated-data/infolog.txt > roster.txt
   ```

   The isolated data directory needs this checkout as `games/Beyond-All-Reason.sdd`
   and the map. The run takes a few minutes; `AIMFIT ROSTERPROGRESS` lines show
   progress and it quits by itself. A subset can be measured with the modoption
   `aimfit_units=armpw,corak`.

2. Generate the table. A slot gets an entry only when the estimate is clearly better
   than the aim piece (see the constants at the top of the script):

   ```sh
   python3 tools/aimfit/generate_aim_from_estimates.py --bar . roster.txt \
     --report roster-report.txt > gamedata/aim_from_estimates.lua
   ```

3. Check the file into the same PR as the model or script change that made it
   necessary.

## Staleness

The generated file stores a fingerprint (sha1 of the unit's model and script files)
per unit. `--check` recomputes them and fails when any unit with an entry changed:

```sh
python3 tools/aimfit/generate_aim_from_estimates.py --bar . --check gamedata/aim_from_estimates.lua
```

Run it after changing a unit's model, script or weapon layout and regenerate the
affected units.

## Notes

* Weapons whose `QueryWeapon` alternates between barrels get one estimate for the
  mean muzzle (half the barrel spacing of residual error). Which barrel fires next
  cannot be predicted from the engine's `QueryWeapon` piece at aiming time: measured
  on Storm, AK and Pawn the relation differs per script and burst state.
* Weapons that cannot attack ground, shields, interceptors, stockpiled and
  manual-fire weapons, and aircraft are skipped; they keep the engine default.
* The gadget needs an engine with `Spring.GetUnitWeaponAimFromPos` (the same
  engine version that introduced `aimFromEstimate`).
