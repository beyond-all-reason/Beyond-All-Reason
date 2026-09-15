# Synced unit death cache

`api_unit_death_cache.lua` owns a shared, read-only lookup table for synced gadgets:

```lua
local isUnitDead = table.ensureTable(GG, "IsUnitDead")

-- Equivalent to Spring.GetUnitIsDead(unitID) ~= false in full-read synced code.
if isUnitDead[unitID] then
    -- The unit is dead or the ID is invalid.
end
```

The table keeps its identity, so consumers may acquire it before the provider
loads. Use it from call-ins or Initialize after the provider has initialized,
not while loading a consumer's file. The provider runs before consumers at
layer -2000000000. Do not write entries or replace its metatable.

A stored `false` means alive; `true` means dead or invalid. An absent entry is
unknown: the metatable queries the engine on the next read. This API deliberately
combines the engine's `true` and `nil` results. It is **not** a drop-in replacement
for every GetUnitIsDead expression, and must not be used inside a restricted
`CallAsTeam` read context or from widgets/unsynced gadgets.

UnitCreated invalidates an entry (including reuse of an ID); UnitDestroyed marks
it dead before later gadgets receive the event. Two death/invalid-entry buckets
rotate every 10 simulation seconds. Entries expire after 10-20 seconds, without
per-entry timestamps. Repeated hits do not extend retention. Expired entries are
queried again, never assumed alive. Memory consists of cached live IDs, recently
dead/invalid IDs and live carrier IDs, not a cumulative history of all deaths.

## Transporters and reloads

The engine sets a transporter's isDead before releasing cargo, then emits its
UnitDestroyed. Cargo damage/unload callbacks can therefore precede that event.
Live transporters are not cached: their reads query the engine until death is
observed. UnitLoaded also invalidates a cached alive value when Lua forcibly
attaches cargo to a unit without transport capacity. Initialize reconstructs
existing carrier relationships and clears cached values, supporting gadget reload
and initialization with existing units. Disabling the provider leaves consumers
with an uncached engine-query metatable rather than stale values.

## Consumer audit

| Gadget / group | Decision |
| --- | --- |
| `unit_target_on_the_move.lua` | Converted the full-read `alwaysSeen` cleanup check on master. This changes no targeting rules. PR #9165's dead/crashing selection fix remains separate. |
| `cmd_build_bugger_off.lua` | Converted its repeated strict alive check while scanning units obstructing builders. |
| `unit_water_depth_damage.lua` | Converted its strict alive check before drowning damage. |
| `unit_waterspeedmultiplier.lua` | Compatible strict alive check, but its movement-data lookup is still required; candidate for a later measured conversion. |
| `unit_transport_dies_load_dies.lua` | Possible in GameFramePost; retains its engine queries for now, including its separate crashing-state query. |
| `unit_custom_weapons_behaviours.lua`, `unit_custom_weapons_overpen.lua` | Repeated projectile checks are candidates; review each call path, including restricted team reads, before converting. |
| `unit_shield_behaviour.lua`, `unit_lightning_splash_dmg.lua`, `unit_collision_damage_behavior.lua` | Damage/reentrant paths need dedicated consumer tests. Some checks use `not GetUnitIsDead`, whose invalid-ID semantics differ. |
| `ai_zombies.lua`, Raptor/Scav spawners | Often pair ValidUnitID with a death check; potential savings, but require mode-specific tests. |
| Reclaim/upgrade helpers, cloak, quick start, territorial domination, objectify, Xmas | Mixed call frequency and nil handling; not converted wholesale. |
| `cus_gl4.lua`, `gfx_nano_particles_gl4.lua`, LuaUI widgets | Unsynced: cannot use this synced GG table. Visibility-sensitive engine queries remain necessary. |

## Validation

Run `runtests unit_death_cache` with cheats/developer mode on a map. The lifecycle
test checks the real carrier-unload ordering, immediate death visibility, and
expiry followed by rechecking an invalid ID. The unit suite covers cold reads,
cache hits (including false), ID reuse across generations, forced carriers,
reload, shutdown, and consumer-first table acquisition.

```sh
# With the repository's normal Lua test environment:
busted spec/luarules/unit_death_cache_spec.lua
```

This is an optimization for repeated full-read checks, not a claim about total
frame time. First reads, transport reads, initialization and event/bucket upkeep
still have costs. Measure the intended workload before migrating more consumers.
