# Torpedo motion constraints and tuning

Torpedoes using `speceffect = "torpwaterpen"` retain the engine's native guidance. The weapon definition controls ordinary homing and accuracy through standard weapon-control values such as `turnrate`, velocity, acceleration, and firing tolerance. The torpedo section of `luarules/gadgets/unit_custom_weapons_behaviours.lua` is primarily a visual trajectory supplement: it shapes the vertical path by smoothing water entry, leveling into surface travel, anticipating terrain, and limiting breaches. Its pitch corrections preserve total projectile speed and, after entry, preserve the current horizontal heading so the engine remains responsible for ongoing horizontal turns.

## Target depth and collision volumes

The gadget currently treats a target aim position at or above **-10 elmos** as a surface target. This is an intentional heuristic rather than an engine-defined unit category: the check uses the engine-provided aim-point elevation, not local water depth or the unit's `minwaterdepth`. BAR's movement reference values provide useful separation around this cutoff, with 8 elmos as the usual minimum ship depth and 15 elmos as the minimum depth for submarine movement. The -10 cutoff therefore tolerates surface-unit aim points that sit slightly below the waterline without applying surface guidance to targets that are clearly submerged. Individual units and underwater structures can use different placement depths, so their actual aim position remains decisive.

A target below -10 is treated as submerged and keeps native underwater tracking, with only predictive terrain avoidance added. The **-12 elmo** value is not the surface/submerged divide: it is the entry-path target depth used when a surface target is far away. The entry target blends from -12 toward the normal **-2 elmo** running depth as the torpedo approaches, allowing a visible dive and rounded return instead of immediately sticking to the surface.

The target aim position decides which guidance path is selected, but the unit collision volume decides whether the projectile actually hits. `collisionvolumescales` defines the volume's dimensions and `collisionvolumeoffsets` moves it relative to the unit. Every surface unit intended to be hit by torpedoes should have a collision volume that extends down to at least the standard -2 elmo torpedo running depth.

## Water entry and turning

Airborne torpedoes may enter the water with a horizontal bearing inherited from the launcher rather than a useful homing direction. On the first underwater update, the gadget points the horizontal velocity toward the target while preserving its horizontal speed and vertical velocity. This correction is recorded in the projectile's runtime state and happens only once. It does not add predictive horizontal lead or stronger continuous turning; subsequent horizontal homing remains engine-controlled.

Surface-target arrival uses the target's horizontal velocity to estimate when the torpedo will arrive. That estimate controls only how quickly the torpedo moves vertically toward its running depth. Submerged targets receive no surface pull. Their native tracking is retained while the gadget looks ahead along the current trajectory, begins terrain avoidance gradually, and fades it near the intended target so the torpedo can complete a downward strike if needed.

## Shallow-water limits

An air-launched torpedo needs enough water depth to redirect its downward velocity before reaching the seabed. The important value is its vertical entry speed at the waterline, which is produced by the weapon's launch direction, `startvelocity`, `weaponacceleration`, `weaponvelocity`, and any projectile gravity. A faster or steeper downward entry requires deeper water, while a slower or shallower entry can recover in less depth.

The gadget cannot smooth an entry until the projectile is in the water. Its entry correction begins around -2 elmos and reaches full strength around -10, so very shallow water may place the seabed inside the correction window and cause an immediate terrain impact. This limit should normally be handled through the individual weapon's launch behavior or accepted as that weapon's minimum usable water depth rather than weakening the shared entry constraints for every torpedo.

## Deep-water ground targets

Manual seabed targets use the submerged-target path, so they receive no pull toward the surface. Native guidance remains responsible for reaching the selected point while the gadget looks four frames ahead for approaching terrain. Avoidance starts gradually within the configured clearance ramp, then fades near the intended impact point so the torpedo can strike the seabed instead of being forced to run parallel to it.

The `/2` and `/3` behavior is represented by the 2:1 submerged-unit and 3:1 ground-target depth-lead ratios. The gadget multiplies the remaining vertical separation by the applicable ratio to produce a horizontal release distance, with a minimum of 36 elmos. For example, with 20 elmos of vertical separation remaining, terrain avoidance starts fading within 40 horizontal elmos of a submerged unit target and within 60 horizontal elmos of a ground target. The larger 3:1 ground ratio releases avoidance earlier and across a wider approach because a ground-targeted torpedo must be allowed to intersect the seabed. The 2:1 unit ratio retains more protection because a submerged unit can normally be hit without striking terrain.

There is no hardcoded maximum supported water depth in the gadget. Water deeper than approximately **400 elmos** should generally be avoided because it begins to exceed the practical model and placement constraints of sea labs as well as the expected operating envelope of underwater weapons. At depths beyond approximately **600 elmos**, the vertical distance alone exceeds the range of most torpedoes. Native firing eligibility, weapon range, travel time, or projectile lifetime may therefore prevent a shot or cause it to expire before arrival. The ground-target controls are primarily a visual fallback for unusual manual seabed shots; they are not intended to override those engine, weapon, and map-design limits.

## Maintenance guidance

Improve a specific weapon's general tracking accuracy in its weapon definition, normally by reviewing `turnrate` together with its speed, acceleration, and firing tolerance. The `tracking_turn_radius` custom parameter does not change engine turning strength; it changes the target-proximity range over which water-entry pitch correction becomes stronger.

Treat the global values in the gadget as one coordinated motion-constraint set rather than independent per-weapon tuning controls. Entry depths and correction strengths shape the water-entry curve, arrival frames control the transition to surface travel, terrain values prevent premature seabed impacts, and breach values constrain shore-launched torpedoes after they enter the water. When changing the shared set, test air-, surface-, submerged-, and shore-launched torpedoes against moving surface units, submerged units, and manual seabed targets in shallow, normal, deep, flat, and sloped water.
