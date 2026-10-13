# Lua attack movement (opt-in)

Requires RecoilEngine [PR #3330](https://github.com/beyond-all-reason/RecoilEngine/pull/3330).
Set the startscript modoption `attackmovementmode=lua` to enable the equivalent
port of native object/ground attack movement. `fallback` installs a callback
that returns false; an unset option keeps the gadget disabled. On engines
without the new APIs the gadget removes itself.

The gadget preserves the native decisions, including the 90% range rule. It
provides a baseline for subsequent policy changes for
[RecoilEngine #3331](https://github.com/beyond-all-reason/RecoilEngine/issues/3331).
It does not interpret `AimWeapon` returning false as a permanent refusal.

`AttackCommandMovement` runs when native mobile command AI evaluates attack
movement, before its range decisions. Return literal true to handle that update;
false/nil delegates to native behavior. This is not a per-shot event. Effects of
movement API calls are immediate, so returning false does not undo them.

## Querying friendly and terrain blockers independently

Inside the callback, `Spring.GetUnitAttackWeaponState(unitID, weaponNum,
avoidFlags?)` returns `eligible, rotate, heading, ownerRotation, targetBorder,
rotateReason, headingReason`. The optional mask replaces the weapon's avoidance
flags **for this query only**. Omit it to retain native flags, as this port does.
Set bits mean ignore; target/range checks always apply.

```lua
local flags = Game.collisionFlags
local friendlyOnly = flags.noGround + flags.noNeutrals + flags.noFeatures + flags.noCloaked
local terrainOnly = flags.noUnits + flags.noFeatures + flags.noCloaked
local _, _, _, _, _, rotateReason, headingReason =
    Spring.GetUnitAttackWeaponState(unitID, weaponNum, friendlyOnly)
```

A policy that advances through terrain obstruction but holds for friendlies can
first check `friendlyOnly`, then query `terrainOnly` independently. That also
handles simultaneous blockers: a single unfiltered result reports only the
first failure. Choose rotate/heading according to the intended chassis
orientation and combine results across the relevant weapons before deciding.
`clear` does not imply aim readiness, reload completion or an actual shot.
Enemy units are ignored as a category by native pre-aim avoidance. The ray
implementation also checks cloaked units independently: `noUnits` does not
include `noCloaked`, so both masks explicitly suppress that extra category.

The shipped port deliberately does not activate that future policy. The engine
companion includes a 56-case blocker/filter integration test and replay
comparison instructions. The BAR spec is
`spec/luarules/attack_movement_spec.lua`.

## Command cleanup

`UnitCommandEnded(unitID, cmdID, cmdTag, reason)` notifies gadgets when the
front command finishes or a command-queue operation ends/interrupts it. Reasons
are `completed`, `removed`, `targetLost` and `interrupted`. It runs before the
next command executes. A front insertion retains the interrupted command for
later resumption; an immediate replacement removes it. Removing an inactive
queued command does not generate this notification. Internal command-AI
subtasks are not a general suspension/resumption API.

Use the tag to discard command-specific Lua state. `Spring.ClearUnitGoal(unitID,
false)` stops movement without issuing `CMD_STOP` or discarding queued commands.
Inspect the next queued command before stopping if it should continue moving.
The shipped equivalent port installs no cleanup policy, so enabling it still
preserves native behavior. The engine lifecycle test demonstrates stop cleanup
for removed/dead attack targets and preserving a queued MOVE.
