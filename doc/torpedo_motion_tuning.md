# Torpedo motion

Torpedo motion is controlled via `speceffect` and a set of tuning factors. These are generally not configurable, but also lack derivation; they are loose facts. The motions they define are pure videogame logic with no physical reasoning. Projectiles do not truly accelerate, hold speeds, etc.; insistence they do is false.

Instead, we program visual arcs that the projectiles are expected to follow through a set of numerical controls defined by their constraints. This file documents this alternative flight plan and how to keep it up to date with engine changes.

Underwater mechanics are less visible just for being underwater. Submarines are often tightly associated with stealth, and a torpedo attack is often an ambush. The projectile is required (as possible) to remain near to the surface, on a relatively level path, and with smooth arcing motions with no jerk, and avoid breaching the surface once underwater. None of these requirements can be met with the engine's pursuit guidance approach to projectile tracking.

## Target depth and collision volumes

Movedefs and unitdefs define the first set of constraints by defining the waterlevel and min/max water depths of every unit. These constraints are prior to those here.

The target's aim position is used to determine which type of guidance to choose. Either the torpedo is diving (avoid when we can) or it is remaining level, near-surface, etc.

The target's collision volume must extend far enough into the water that breaching can be avoided when attempting to hit it.

## Water entry

Torpedoes fired above the surface try not to run aground instantly after entering the water for ease of using the units.

Units with `hoverattack=true` may fire torpedoes in a bearing inherited from the launcher's movement rather than a useful firing direction. These cannot receive too much horizontal correction at the entry point, even so. A minor adjustment is the best we can do here to avoid producing jerky, unpredictable, nonsmooth motions.

## Shallow-water targets

Raised-launcher torpedoes need sufficient water depth to redirect before exploding on the ground. They enter the water with high vertical velocity components that are softened but not zeroed, only once the projectile enters the water.

## Deep-water targets

Submerged targets have a separate guidance path. The projectile may need to avoid grounding in shallows, still, if a deep target is far away; there is no relation to the target depth.

A target may be deeper than a weapon's range, which is left up to the engine and any other game code post-entry. Not our problem.

## Maintaining this code

Weapondefs are the proper place for tuning. The torpedo motion code is shared by many weapons and must be left in stable condition outside bugfixes.

When changing common constraints anyway, test air-, surface-, submerged-, and shore-launched torpedoes against moving surface units, submerged units, and manual seabed targets in shallow, normal, deep, flat, and sloped water.
