# Game Economy Optimization Plan

## Summary of Changes Implemented

### 1. Config Caching (`shared_config.lua`)
**Status**: ✅ Complete

Cached `getTaxConfig()` results at module level. ModOptions are immutable during a game, so we only need to compute once.

```lua
local cachedTax = nil
local cachedThresholds = nil

function M.getTaxConfig(springRepo)
  if cachedTax then
    return cachedTax, cachedThresholds
  end
  -- ... compute once, cache forever ...
end
```

**Impact**: Eliminates table allocation + ModOptions lookup every frame.

---

### 2. Table Pooling for ProcessEconomy (`game_resource_transfer_controller.lua`)
**Status**: ✅ Complete

Replaced per-frame table allocations with object pooling:

```lua
local resultCache = {}
local resultPool = {}
local poolIndex = 0

local function GetPooledTable()
  poolIndex = poolIndex + 1
  if not resultPool[poolIndex] then
    resultPool[poolIndex] = {}
  end
  return resultPool[poolIndex]
end
```

The `resultCache` array is reused each frame. Inner entry tables are pooled and recycled.

**Impact**: Eliminates 2*N table allocations per frame (where N = team count).

---

### 3. Ledger Pre-initialization (`economy_waterfill_solver.lua`)
**Status**: ✅ Complete

Pre-initialize ledger entries for ALL teams at the start of `Solve()`:

```lua
for teamId in pairs(teamsList) do
  allLedgers[teamId] = {
    [ResourceType.METAL] = { sent = 0, received = 0, untaxed = 0, taxed = 0 },
    [ResourceType.ENERGY] = { sent = 0, received = 0, untaxed = 0, taxed = 0 },
  }
end
```

This guarantees every team has a complete ledger structure, eliminating:
- `or {}` fallbacks in consumers
- `if not perTeam` / `if not summary` checks in the merge loop
- Potential nil access bugs

**Impact**: Slightly more upfront allocation, but eliminates branching and defensive coding.

---

### 4. Removed Duplicate getTaxConfig (`economy_waterfill_solver.lua`)
**Status**: ✅ Complete

The solver had its own `getTaxConfig` function that duplicated `shared_config.lua`. Now uses the shared cached version.

---

### 5. Eliminated `or 0` Patterns
**Status**: ✅ Complete

Removed defensive `or 0` fallbacks in:
- `ApplyResults()` in `game_resource_excess_controller.lua`
- `collectMembers()` threshold lookup

These were masking potential nil bugs and adding unnecessary runtime overhead.

---

### 6. PolicyCache Table Pooling (`resource_transfer_synced.lua`)
**Status**: ✅ Complete

The PolicyCache was a major source of GC pressure due to:
- Creating a new `ResourcePolicyResult` table for every sender×receiver×resource combination (N² × 2 tables per update)
- Creating a new `parts` table for every serialization call

**Optimizations applied**:

1. **Pooled PolicyResult table** - Reuses the same table per resource type:
```lua
local policyResultPool = {}

-- Inside calcResourcePolicyResult:
local result = policyResultPool[resourceType]
if not result then
  result = {}
  policyResultPool[resourceType] = result
end
-- Populate fields directly
result.senderTeamId = ctx.senderTeamId
-- ... etc
return result
```

2. **Pooled Serialization Buffer** - Reuses buffer in `team_transfer_cache.lua`:
```lua
local serializeBuffer = {}

function M.Serialize(fields, obj)
  local n = 0
  for fieldName, fieldType in pairs(fields) do
    -- ... populate serializeBuffer ...
  end
  -- Clear leftover entries
  for i = n + 1, #serializeBuffer do
    serializeBuffer[i] = nil
  end
  return table.concat(serializeBuffer, ":")
end
```

3. **Cached SharedConfig include** - Moved `VFS.Include` to module level instead of inside `UpdatePolicyCache`.

**Impact**: Eliminates 2×N² table allocations per PolicyCache update cycle.

---

## Remaining Optimization Opportunities

See detailed plans in:
- [Table Pooling Round 2](table_pooling_round2.md) - Exhaustive allocation map and scratch buffer implementation
- [C++ Waterfill Math Primitives](cpp_waterfill_service.md) - Engine-side lift/delta computation

### Short-term (Lua-only)

**Staggered Policy Updates**: Instead of updating all N² policy combinations every 30 frames, update one sender's policies per frame. Spreads the 800μs spike across 16 frames.

**Member Table Pooling**: The `collectMembers()` function creates new tables for each member every frame. See [Table Pooling Round 2](table_pooling_round2.md) for the complete allocation map.

**Cumulative Updates Batching**: `updateCumulative()` calls `SetTeamRulesParam` individually. Could batch into a single engine call if the API supports it.

### Medium-term (Engine-side)

**C++ Waterfill Primitives**: Move binary search lift computation to C++ while keeping all game policy in Lua. Expected ~10x speedup on solver math. See [C++ Waterfill Math Primitives](cpp_waterfill_service.md).

---

## Type Guarantees

The refactored code relies on these invariants:

1. **`BuildTeamData` guarantees**: `team.metal.current`, `team.metal.storage`, `team.energy.current`, `team.energy.storage` are always non-nil numbers when the team entry exists.

2. **`Solve` guarantees**: `allLedgers[teamId][resourceType]` exists for every team in `teamsList`, with all fields (`sent`, `received`, `untaxed`, `taxed`) initialized to 0.

3. **`getTaxConfig` guarantees**: `thresholds[ResourceType.METAL]` and `thresholds[ResourceType.ENERGY]` are always non-nil numbers.

