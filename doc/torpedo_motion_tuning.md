# Torpedo motion

The engine handles ordinary homing. The torpedo gadget supplements it with rounded entry, surface-depth tracking, terrain avoidance, and shore-launcher water-exit protection. Hitting the target takes priority; the shared motion rules shape the curve where there is room.

## Steering

Surface-bound torpedoes choose an aim depth and a horizontal distance over which to reach it. The desired pitch is `atan2(aimDepth - projectileY, aimDistance)`. Entry and surface travel use the same pitch controller.

Ordinary pitch changes are limited by the weapon's native turning capability. The Lua `WeaponDefs.turnRate` value is already converted by the engine. The engine's normalized tangent steering step turns through `atan(turnRate)`, which supplies our ordinary per-frame limit. At a given speed, the approximate turning radius is `speed / pitchStep`. Faster travel therefore needs more turning room.

The previous frame's corrected pitch provides the reference for the next step. This accounts for native pitch steering between gadget updates. The gadget retains the engine's current horizontal heading and reconstructs velocity at the new pitch while preserving total speed. Changing pitch redistributes speed between horizontal and vertical motion and can affect accuracy.

Close shots can require tighter turns. A circle tangent to the current path and passing through the aim point has curvature `2 * sin(pitchError) / distanceToAim`. Multiplying curvature by speed gives the approximate pitch change needed per frame. We allow that to exceed the ordinary weapon-derived limit when necessary. For errors beyond 90 degrees, the calculation uses the 90-degree value to keep recovery responsive. This is an explicit close-target exception.

This first pass replaces the entry/surface percentage-strength ramps. The tested aim depths, arrival margins, and submerged terrain-release rules remain in place for comparison.

## Target depth and collision volumes

Movedefs and unitdefs establish unit placement and movement limits. The target's aim position selects guidance: at or above -10 elmos it is treated as a surface target. This allowance accommodates surface units whose aim points are slightly submerged.

Surface travel aims for -2 elmos. Surface units intended to receive torpedo hits need collision volumes that extend down to at least that depth.

## Water entry

A distant surface target gives the projectile room to dive before returning upward. The entry aim depth blends from -12 toward -2 as the target approaches within 180 elmos. Surface-target entry correction begins below -2.

The aim point is brought forward using the arrival margin so the torpedo can finish its curve before reaching the target. It is bounded by the remaining target distance to preserve close-shot recovery. Once the steep descent has flattened, the aim depth becomes the normal running depth.

Hover-attack launchers receive a one-time horizontal correction toward the target underwater, preserving horizontal speed and vertical velocity. The angle can be large. Bombers and other launchers retain their entry heading for native homing.

## Surface arrival

Arrival prediction estimates travel time from horizontal distance and speed, then updates the estimate using target velocity when available. Future target turns remain a source of error.

The existing 20-frame lead and eight-frame minimum correction interval position the vertical aim point ahead of arrival. Very close shots shorten that interval to the remaining arrival time. When visibility is lost, the retained target class allows surface guidance to continue using a local lookahead.

A climbing torpedo also needs room to level out. For a circular turn, the remaining rise is approximately `radius * (1 - cos(pitch))`. Guidance requests a level pitch when that rise would reach running depth, allowing the transition to begin while the torpedo is still below its travel depth.

## Shallow-water targets

Steep, fast drops need room to recover. For surface-bound shots, the same circular-arc calculation estimates the depth needed to flatten a descent. The check samples terrain here and four frames ahead, reserves the next downward step, and permits stronger recovery when the ordinary turn would reach the seabed.

The six-elmo terrain clearance remains a recovery goal. Extreme drops or rapidly changing terrain can still exceed what these samples anticipate.

## Deep-water targets

Submerged targets retain the engine's pitch and horizontal tracking. The existing slope-aware terrain correction remains active for the `torpwaterpen` path. It projects four frames ahead and progressively flattens a descent near terrain, with a 45% velocity blend. That terrain request is capped at level flight to reduce slope-induced breaches.

Avoidance fades near the intended destination. Its horizontal release distance is twice the remaining vertical separation for submerged units and three times for ground targets, with a 36-elmo minimum. A second fade uses direct distance inside 36 elmos. Ground shots release earlier so they can intersect the selected seabed point. These release ratios and the terrain blend are retained tested choices.

Range, projectile lifetime, and engine firing eligibility still limit very deep shots.

## Water-exit protection

Shore weapons marked `avoid_leaving_water` retain their additional +2-elmo ceiling check. After a breach, vertical velocity is redirected downward according to height above water. This emergency adjustment can change total speed.

## Maintaining this code

Use weapon definitions for individual weapon tuning. The legacy `tracking_turn_radius` custom parameter is no longer read by this gadget; ordinary pitch steering now uses `WeaponDefs.turnRate`. Existing `speceffect` registration is retained for this local steering trial.

Low-turn-rate weapons can now describe deeper entry arcs. Test these first, especially steep Legion frigate shots. Also test hover gunships, bombers, underwater launchers, and shore launchers against moving surface units, submerged units, and manual seabed targets in shallow, normal, deep, flat, and sloped water.

The mathematical checks cover speed, heading, recovery limits, and terrain-regression cases. Live testing is needed for collision volumes, moving targets, projectile lifetimes, and the appearance of the curves.
