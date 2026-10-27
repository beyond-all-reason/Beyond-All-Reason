# Lua attack movement

Requires RecoilEngine #3330. Set `attackmovementmode=lua` in the startscript to
use the controller, `fallback` to exercise native fallback, or omit it to leave
native movement in charge. This migration preserves the existing policy,
including the 90% range threshold; it does not fix the gameplay issues in #3331.

`AttackCommandMovement(unitID, cmdTag, cmdID, cmdOptions, targetID, x, y, z,
temporary)` runs before native movement decisions. Return literal `true` to
handle the update. `false`/`nil` delegates to native movement. Existing command
initialization, completion checks and weapon firing remain native. `temporary`
identifies an engine-generated suborder, such as an attack during fight.

The engine supplies four focused capabilities:

| Call | Purpose |
| --- | --- |
| `TestUnitAttackWeapon(unitID, weaponNum, options?)` | Test one firing geometry for the current command target |
| `GetUnitAttackTargetPosition(unitID)` | Get the target midpoint with the attacking allyteam's sensor error, or the ground command position |
| `SetUnitFacingTarget(unitID, x, y, z, radius)` | Ask the movement controller to face a position without stopping or assigning a target |
| `FinishUnitAttackCommand(unitID)` | Finish the active attack without discarding queued successors |

The query and finish calls require the active callback for the same controlled
unit. They reject a command or target invalidated during dispatch. Handler
dispatch stops after the first `true` or an invalidated command/owner/target.
Effects of existing movement/target calls are immediate, not transactional.

Target assignment uses existing `SetUnitTarget`; stopping uses
`ClearUnitGoal(unitID, false)`. Normal `SetUnitMoveGoal` calls for the current
callback's unit go through its command AI, retaining an active matching goal
instead of restarting its path. No new setter argument is needed. Calls outside
the callback, to other units, or with `moveRaw=true` keep their independent
movement behavior.

## Weapon queries

```lua
local clear, reason, blockerType, blockerID = Spring.TestUnitAttackWeapon(
    unitID, weaponNum, { orientation = "heading", avoidFlags = flags }
)
```

`rotate` tests the native object-target rotation solution. `heading` tests the
chassis facing the target. Defaults are `rotate` for unit targets and `heading`
for ground targets. A ground `rotate` query returns `notChecked`.

For candidate geometry, use `orientation="heading"`, `position={x,y,z}` and an
explicit signed `heading`. `useMuzzle=true` selects current muzzle geometry.
These tests translate the current piece pose; they do not predict animation,
terrain alignment, water transitions or path reachability. `clear` does not
mean the script accepts the target, aiming is finished, or the weapon is ready.

Omitting `avoidFlags` retains the weapon's flags. An explicit mask replaces them
for this query only. Bits mean ignore. `noMobileFriendlies` and
`noStaticFriendlies` distinguish movement capability, not current velocity.
The native pre-aim checks do not test enemies as a separate obstacle category.
Use `noCloaked` as well as `noUnits` when excluding all units from ray tests.

The result reports the first failed test and optional blocker identity in native
scan order, not all blockers or necessarily the nearest. Query categories
separately for simultaneous terrain and allied-unit obstruction.
`GetUnitWeaponState(unitID, weaponNum, "onlyForward")` reports the actual weapon's
chassis-turn requirement, including weapon-type overrides of its definition.

## Gameplay decisions

The callback runs even inside engagement range. A game can keep approaching a
terrain obstruction, probe a sideways position around friendly units, maintain
artillery distance, or circle a target by choosing different movement goals.
Candidate firing geometry does not establish that a path to the position exists.

Weapon geometry does not report a unit script's acceptance of a shot.
`AimWeapon=false` can also mean that aiming is still in progress. A policy that
needs to distinguish rejection from ongoing aiming must receive an explicit
signal from its game-side unit script; it can then keep moving on subsequent
callbacks. No special engine return value or forced float emulation is required.

Stopping residual movement after the active command is removed or its target
dies is a separate native command-lifecycle fix (#3333). Normal callback movement uses the native command-AI goal path so that #3333
can associate it with the attack. Independent/raw Lua goals remain outside that
ownership. This callback does not run for an attack that has already been
removed, and does not itself implement the stop fix.
It does not add a general command-ended notification or change Repeat (#3368).

## State ownership

Lua owns the engagement fraction, chase horizon/speed multiplier, strafe geometry,
repath tolerance, target-border multiplier and retry interval. Matching native
constants are intentionally left in the fallback implementation: that movement
code does not run on an update handled by Lua, so these are alternative policies,
not two active settings that must be synchronized. A future BAR policy can change
them without changing the engine.

Live engagement range, positions, velocity, sensors, weapon flags and movement
goals are read through existing getters. They are not cached UnitDef substitutes.
The engine still owns targeting geometry and sensor error.

Lua keeps `lastApproach` and the evolving strafe side per unit. They survive
command changes, matching the native controller's lifetime, and are cleared on
`UnitDestroyed`. `GetUnitMoveTypeData().strafeLeft` supplies the initial native
random side once; Lua then owns changes. This avoids consuming extra simulation
RNG values or exporting the RNG itself. The native side is not kept synchronized
with Lua. This supplied controller therefore runs consistently from game start;
hot switching/reloading controllers is not a supported state handover.

## Validation

The engine's `test/validation/attack_movement/` contains isolated replay,
blocker and dispatch tests. The same controller file is used for game
and validation. Native/fallback replay comparisons require exact observable-state
matches. A diagnostic shadow run compares Lua's planned actions with actual native
actions on the same live state, with exact discrete choices and a separately
reported destination tolerance. Active Lua replay runs and controlled scenarios
check the resulting simulation; a numeric divergence is investigated rather than
"fixed" by exposing more implementation details.

Before rebasing, the 2026-10-27 refactor matched engine parent `bb3ff79675` in all three
replay windows (36,000 + 18,000 + 18,000 frames) for native, false-fallback and
active Lua modes, plus 5,280 controlled scenario frames. Shadow comparisons
matched 4,018 replay updates and 280 scenario updates exactly, including numeric
arguments; no tolerance was needed. Observer state hashes also matched native.
These are Lua-visible state comparisons over the tested windows, not proof of
identical behavior for every replay or all internal engine state.

The cleanup also passed four goal-ownership cases both without and with #3333:
command-owned movement stops on target deletion only with that fix; independent
Lua goals, raw callback goals and queued MOVE successors continue as intended.
One diagnostic shadow attempt crashed in a QTPFS pathfinding worker; repeating
that replay under GDB completed with matching decisions. The crash cause remains
unresolved, so successful parity runs are not a claim of crash-free operation.

The master rebase uses engine `30a80f69e3` and BAR `42bd8f6512`. The rebased
controller and synthetic-callin tests pass (41 cases), as do 86 blocker cases
and six dispatch cases using the current BAR game and its updated handler.
The 22 movement scenarios also match across all four modes on the current BAR
game (5,280 frames), in addition to the historical-game scenarios.
The three replay windows (72,000 frames per mode) and historical scenarios
also match the freshly built engine master `30a80f69e3` exactly in native,
false-fallback and active Lua modes. Historical replay comparisons use BAR
`c6b9114b50` consistently across modes; current-game integration is a separate
check. All post-rebase runs completed without crashes.

OpenAI Codex assisted this refactor and its automated checks. Human API review
and interactive gameplay validation remain necessary.
