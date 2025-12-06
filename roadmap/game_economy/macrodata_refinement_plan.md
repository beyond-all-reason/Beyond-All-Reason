# Macrodata Refinement Plan

## Summary

This plan addresses type contract boundaries between the engine and Lua game economy system, timing consistency for audit comparisons, function naming clarity, and code reuse.

---

## Design Philosophy: Two Distinct Approaches

The economy system supports two resolution paths with **intentionally different design philosophies**:

### Path A: ProcessEconomy (Synchronous Handshake)

- **Design**: Single atomic call/return, engine blocks until Lua returns
- **Data Flow**: Engine provides full state → Lua transforms → Engine applies result
- **Stats Contract**: Engine parses stats from the return value
- **Boundary Crossings**: O(1) - minimal crossing overhead
- **Trade-off**: Simpler mental model, but engine blocks during Lua execution

### Path B: ResourceExcess (Many-Method API)

- **Design**: Event notification + explicit setter calls
- **Data Flow**: Engine notifies → Lua queries/reconstructs → Lua calls setters
- **Stats Contract**: Lua calls `AddTeamResourceStats` explicitly
- **Boundary Crossings**: O(N) - more crossings, but more granular control
- **Trade-off**: More complex, but potentially more flexible

### Blocking Behavior

ProcessEconomy uses **synchronous blocking**: the engine waits for Lua to return before continuing the frame. This is intentional:

- Economy resolution is on the critical path
- No drift between solver and engine state
- Engine never reads stale resource data

If performance is a concern, optimize the solver.

---

## Task 1: Unified EconomyTeamResult Return Type

### Problem

ProcessEconomy currently returns stats embedded in ResourceData, conflating input and output types. The return should be:
- **Simple**: Flat array, one iteration to process
- **Complete**: Contains both resource state and stats
- **Clean**: No excess field (engine can calculate from pre-clamp values)

### Solution

Add a unified `EconomyTeamResult` type to `spring.lua`:

```lua
---@class EconomyTeamResult
---@field teamId number
---@field resourceType ResourceName
---@field current number
---@field sent number
---@field received number

-- ProcessEconomy returns: EconomyTeamResult[]
-- One entry per team per resource (2 entries per team: metal + energy)
```

### Why This Structure

- **Flat array**: Engine iterates once, no nested lookups
- **teamId + resourceType**: Matches input structure, symmetric contract
- **No excess**: ProcessEconomy doesn't need it (engine knows pre-clamp values)
- **Unified**: Current + stats in one object, not separated

### Files to Modify

- `types/spring.lua`: Add `EconomyTeamResult`
- `luarules/gadgets/game_resource_transfer_controller.lua`: Build flat result array
- `common/luaUtilities/economy/bar_economy_waterfill_solver.lua`: Return format adjustment

### Return Value Construction

```lua
-- In game_resource_transfer_controller.lua ProcessEconomy
local result = {}

for teamId, team in pairs(updatedTeams) do
    local ledger = allLedgers[teamId]
    
    result[#result + 1] = {
        teamId = teamId,
        resourceType = SharedEnums.ResourceType.Metal,
        current = team.metal.current,
        sent = ledger.metal.sent,
        received = ledger.metal.received,
    }
    
    result[#result + 1] = {
        teamId = teamId,
        resourceType = SharedEnums.ResourceType.Energy,
        current = team.energy.current,
        sent = ledger.energy.sent,
        received = ledger.energy.received,
    }
end

return result
```

---

## Task 2: Remove Ledger Fields from ResourceData Mutation

### Problem

The waterfill solver currently mutates `resource.sent` and `resource.received` directly on the ResourceData objects:

```lua
resource.sent = sender.costSpent
resource.received = receiver.received
```

This conflates the input/output contract and adds fields to the engine's input type.

### Solution

1. Stop mutating `resource.sent` / `resource.received` on the input ResourceData
2. Continue using `EconomyFlowLedger` for internal tracking (already exists)
3. Build the return value explicitly from the ledger

### Files to Modify

- `common/luaUtilities/economy/bar_economy_waterfill_solver.lua`

### Key Changes in `allocateGroup`:

- Remove these lines that mutate the input resource:
  ```lua
  resource.sent = sender.costSpent
  resource.received = receiver.received
  ```
- The ledger already tracks `sent`, `received`, `untaxed`, `taxed`

---

## Task 3: Type Reuse Decision - ResourceTransferResult vs EconomyFlowLedger

### Analysis

- `ResourceTransferResult` (team_transfer.lua): For **on-demand player-initiated transfers**
  - Includes `success`, `policyResult`, `senderTeamId`, `receiverTeamId`
  - Different use case than automatic slider-based sharing

- `EconomyFlowLedger` (team_transfer.lua): For **per-team flow tracking per resource type**
  - Includes `sent`, `received`, `untaxed`, `taxed`
  - Already used by waterfill solver

### Decision

**Keep them separate.** The waterfill solver should continue using `EconomyFlowLedger` for internal tracking. `ResourceTransferResult` serves a different purpose (discrete player-initiated transfers with policy context).

No changes needed - the existing `EconomyFlowLedger` is appropriate.

---

## Task 4: Engine ResourceBar Display Capping

### Problem

In `game_economy=1` mode, the resource bar can momentarily display `current > storage` before the Lua economy controller runs. This shows impossible values between frames.

### Location

`spring/rts/Game/UI/ResourceBar.cpp` lines 105-117:

```cpp
const float sx[] = {
  (rcs.metal != 0.0f)? ((rcr.metal / rcs.metal) * metalbarlen): 0.0f,
  rshr.metal * metalbarlen
};
// Similar for energy at line 117
```

### Solution

Always cap display to storage. Displaying `current > storage` is never valid - resources cannot exceed storage capacity.

```cpp
const float metalRatio = (rcs.metal != 0.0f)
  ? (std::min(rcr.metal, rcs.metal) / rcs.metal)
  : 0.0f;
const float sx[] = {metalRatio * metalbarlen, rshr.metal * metalbarlen};

// Same for energy
const float energyRatio = (rcs.energy != 0.0f)
  ? (std::min(rcr.energy, rcs.energy) / rcs.energy)
  : 0.0f;
```

### Benefit

- Simpler code (no conditional on game_economy)
- Correct regardless of mode (can't have more than storage)
- No nested ternary

---

## Task 5: Explicit Type Cast for ResourceExcess Team Data

### Problem

In `game_resource_excess_controller.lua`, the `BuildTeamData` function builds team data inline without explicit type annotation:

```lua
teams[#teams + 1] = {
    id = teamID,
    allyTeam = allyTeam,
    metal = {
        current = metalWithExcess,
        storage = mSto or 1000,
        shareSlider = mShare or 0.99,
        excess = metalExcess,  -- This field shouldn't be here
    },
    ...
}
```

### Solution

Cast the result explicitly to `TeamResourceData[]` and ensure the structure matches the type used by `game_resource_transfer_controller.lua`.

### Files to Modify

- `luarules/gadgets/game_resource_excess_controller.lua`

### Changes

Remove the `excess` field from the inline ResourceData (it's tracked separately) and ensure type consistency:

```lua
---@type TeamResourceData
local teamData = {
    id = teamID,
    allyTeam = allyTeam,
    isDead = false,
    metal = {
        resourceType = "metal",
        current = metalWithExcess,
        storage = mSto or 1000,
        shareSlider = mShare or 0.99,
    },
    energy = {
        resourceType = "energy",
        current = energyWithExcess,
        storage = eSto or 1000,
        shareSlider = eShare or 0.95,
    }
}
teams[#teams + 1] = teamData
```

---

## Task 6: Standardize Stopwatch Timing Tags + Analysis Mapping

### Problem

The timing tags are inconsistent between ProcessEconomy and ResourceExcess paths, making apples-to-apples comparison difficult in audit analysis:

**Shared Lua**
- `WaterfillSolver`

**ProcessEconomy path** (`game_resource_transfer_controller.lua`):
- `Solver`, `PostMunge`, `PolicyCache`
- (No PreMunge - C++ already prepared data via `CppMunge`)

**ResourceExcess path** (`game_resource_excess_controller.lua`):
- `BuildTeamData`, `ApplyResults`

**C++ side** (from engine audit logs):
- `CppMunge`, `LuaTotal`, `CppSetters`

### Solution

#### Part 1: Functional Log Tags (Mutually Exclusive)

Each tag should be:
- Unique and descriptive of its source
- Logged via `AuditLog` for consistency
- Mutually exclusive (no overlap)

| Raw Tag | Source | Description |
|---------|--------|-------------|
| `PE_CppMunge` | Engine C++ | Build TeamResourceData[] tables |
| `PE_Solver` | ProcessEconomy Lua | Waterfill algorithm |
| `PE_PostMunge` | ProcessEconomy Lua | Build return array |
| `PE_PolicyCache` | ProcessEconomy Lua | Update policy cache |
| `PE_CppSetters` | Engine C++ | Parse return, apply to teams |
| `PE_Overall` | Engine C++ | Aggregate timing for ProcessEconomy |
| `RE_CppMunge` | Engine C++ ⚠️ | Build excess table (needs instrumentation) |
| `RE_LuaMunge` | ResourceExcess Lua | Reconstruct TeamResourceData |
| `RE_Solver` | ResourceExcess Lua | Waterfill algorithm |
| `RE_PostMunge` | ResourceExcess Lua | Apply via setters |
| `RE_PolicyCache` | ResourceExcess Lua | Update policy cache |
| `RE_CppSetters` | Engine C++ ⚠️ | Setter call overhead (needs instrumentation) |
| `RE_Overall` | Engine C++ ⚠️ | Aggregate timing (needs instrumentation) |

**Note:** Tags marked ⚠️ require engine-side instrumentation to be added.

#### Part 2: Category Mapping for Analysis

Map raw tags to display categories for comparison:

```python
# In log_analysis/parser.py or notebooks
TIMING_CATEGORIES = {
    'DataPrep': ['PE_CppMunge', 'RE_CppMunge', 'RE_LuaMunge'],
    'Solver': ['PE_Solver', 'RE_Solver'],
    'ResultApply': ['PE_PostMunge', 'PE_CppSetters', 'RE_PostMunge', 'RE_CppSetters'],
    'PolicyCache': ['PE_PolicyCache', 'RE_PolicyCache'],
    'Overall': ['PE_Overall', 'RE_Overall'],
}

# Note: RE_CppMunge, RE_CppSetters, RE_Overall require engine instrumentation

def get_category(metric: str) -> str:
    for category, tags in TIMING_CATEGORIES.items():
        if metric in tags:
            return category
    return 'Other'
```

### Files to Modify

#### Lua (log tags)
- `luarules/gadgets/game_resource_transfer_controller.lua`: Prefix with `PE_`
- `luarules/gadgets/game_resource_excess_controller.lua`: Prefix with `RE_`, rename tags

```lua
-- ProcessEconomy controller (no PreMunge - C++ does CppMunge)
stopwatch:Breakpoint("PE_Solver")
stopwatch:Breakpoint("PE_PostMunge")
stopwatch:Breakpoint("PE_PolicyCache")

-- ResourceExcess controller
stopwatch:Breakpoint("RE_LuaMunge")
stopwatch:Breakpoint("RE_Solver")
stopwatch:Breakpoint("RE_PostMunge")
stopwatch:Breakpoint("RE_PolicyCache")
```

#### Analysis Tools Update

Update the following files to use the new timing tag categories:

**`log_analysis/parser.py`**:
Add the `TIMING_CATEGORIES` dict and a `get_category()` helper function:

```python
TIMING_CATEGORIES = {
    'DataPrep': ['PE_CppMunge', 'RE_CppMunge', 'RE_LuaMunge'],
    'Solver': ['PE_Solver', 'RE_Solver'],
    'ResultApply': ['PE_PostMunge', 'PE_CppSetters', 'RE_PostMunge', 'RE_CppSetters'],
    'PolicyCache': ['PE_PolicyCache', 'RE_PolicyCache'],
    'Overall': ['PE_Overall', 'RE_Overall'],
}

def get_category(tag: str) -> str | None:
    """Map a timing tag to its category for grouped analysis."""
    for category, tags in TIMING_CATEGORIES.items():
        if tag in tags:
            return category
    return None

def get_path(tag: str) -> str | None:
    """Extract path (PE or RE) from a timing tag."""
    if tag.startswith('PE_'):
        return 'ProcessEconomy'
    elif tag.startswith('RE_'):
        return 'ResourceExcess'
    return None
```

**`log_analysis/timing_comparison.ipynb`**:
- Import `TIMING_CATEGORIES`, `get_category`, `get_path` from parser
- Add a cell to group timing data by category for side-by-side comparison
- Create charts comparing Path A vs Path B by category

**`log_analysis/waterfill_analysis.ipynb`**:
- Import `TIMING_CATEGORIES`, `get_category`, `get_path` from parser
- Update timing breakdown charts to use category groupings
- Add path-based filtering for focused analysis

### Testing

Run `lx test` to verify changes don't break existing functionality.

---

## Task 7: Rename ProcessEconomy → Solve in WaterfillSolver

### Problem

The function `WaterfillSolver.ProcessEconomy` creates ambiguity with the engine's `ProcessEconomy` callin. The solver function should have a distinct name.

### Solution

Rename:
- `WaterfillSolver.ProcessEconomy` → `WaterfillSolver.Solve`

The wrapper function in `resource_transfer_synced.lua` can become:
- `Gadgets.WaterfillSolve` (or just continue delegating transparently)

### Files to Modify

- `common/luaUtilities/economy/bar_economy_waterfill_solver.lua`: Rename function
- `common/luaUtilities/team_transfer/resource_transfer_synced.lua`: Update call
- `luarules/gadgets/game_resource_excess_controller.lua`: Update call
- `luarules/gadgets/game_resource_transfer_controller.lua`: Update call (via ResourceTransfer.ProcessEconomy → WaterfillSolve)

### Signature Parity

Maintain the same parameters:
```lua
---@param springRepo ISpring
---@param teamsList table<number, TeamResourceData>
---@param frame number?
---@return table<number, TeamResourceData> teamId -> resourceData
---@return EconomyFlowSummary
function Gadgets.Solve(springRepo, teamsList, frame)
```

---

## Task 8: Reuse Cumulative Tracking from resource_transfer_synced

### Problem

The `ApplyResults` function in `game_resource_excess_controller.lua` duplicates cumulative tracking logic that already exists in `resource_transfer_synced.lua`:

```lua
-- In game_resource_excess_controller.lua (duplicated)
local mSent = springRepo.GetTeamRulesParam(team.id, "cumulativeMetalSent") or 0
springRepo.SetTeamRulesParam(team.id, "cumulativeMetalSent", mSent + (team.metal.sent or 0))
```

```lua
-- In resource_transfer_synced.lua (reusable)
function Gadgets.RegisterPostTransfer(ctx, transferResult)
  local cumulativeParam = Shared.GetCumulativeParam(ctx.resourceType)
  local cumulativeSent = tonumber(ctx.springRepo.GetTeamRulesParam(transferResult.senderTeamId, cumulativeParam))
  ctx.springRepo.SetTeamRulesParam(ctx.senderTeamId, cumulativeParam, cumulativeSent + transferResult.sent)
end
```

### Solution

Extract a simpler utility function that can be called by both paths:

```lua
-- In resource_transfer_shared.lua or new utility
function UpdateCumulativeSent(springRepo, teamId, resourceType, amountSent)
  local param = Shared.GetCumulativeParam(resourceType)
  local current = tonumber(springRepo.GetTeamRulesParam(teamId, param)) or 0
  springRepo.SetTeamRulesParam(teamId, param, current + amountSent)
end
```

Then both controllers can call this shared function.

### Files to Modify

- `common/luaUtilities/team_transfer/resource_transfer_shared.lua`: Add utility function
- `luarules/gadgets/game_resource_excess_controller.lua`: Use shared function
- `common/luaUtilities/team_transfer/resource_transfer_synced.lua`: Optionally refactor to use same

---

## Task 9: Confirm SetUnitTransferController Implementation

### Current Status

The implementation exists in `luarules/gadgets/game_unit_transfer_controller.lua`:

```lua
-- Lines 203-213
if Spring.SetUnitTransferController then
  ---@type GameUnitTransferController
  local controller = {
    AllowUnitTransfer = UnitTransferController.AllowUnitTransfer,
    TeamShare = UnitTransferController.TeamShare
  }
  Spring.SetUnitTransferController(controller)
end
```

### Engine Contract (from LuaSyncedCtrl.cpp)

Required functions:
- `AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture) -> boolean`
- `TeamShare(srcTeamID, dstTeamID)`

### Verification Needed

1. Confirm the engine's `SetUnitTransferController` is being called (check logs for success message)
2. Confirm the fallback gadget callins (`AllowUnitTransfer`, `TeamShare`) are still working as backup

### Status

**Already implemented.** The controller registers both the engine controller and maintains gadget callins as fallback. No changes needed unless testing reveals issues.

---

## Implementation Order

1. **Task 1** - Explicit EconomyStats return type (foundational)
2. **Task 2** - Waterfill solver refactor (depends on Task 1 types)
3. **Task 3** - No action needed (decision documented)
4. **Task 4** - Engine-side change (independent, can be done in parallel)
5. **Task 5** - Type cast for ResourceExcess team data
6. **Task 6** - Standardize stopwatch tags
7. **Task 7** - Rename ProcessEconomy → Solve
8. **Task 8** - Reuse cumulative tracking
9. **Task 9** - Verification only (no implementation needed)

### Dependency Graph

```
Task 1 (types) ──┬─► Task 2 (waterfill refactor)
                 │
Task 5 (type cast) ──► Task 6 (timing tags)
                       │
Task 7 (rename) ◄──────┘
                       │
Task 8 (cumulative) ◄──┘

Task 4 (engine) ─► Independent
Task 9 (verify) ─► Independent
```

---

## Risk Assessment

| Task | Risk | Mitigation |
|------|------|------------|
| Task 1 | Medium - contract change | Engine PR needed to parse new format |
| Task 2 | Medium - behavior change | Existing tests + audit logging |
| Task 4 | Low - display-only | Only affects `game_economy=1` mode |
| Task 5 | Low - type annotation | No runtime change |
| Task 6 | Low - string changes | Audit log analysis will validate |
| Task 7 | Low - rename | Find/replace, tests verify |
| Task 8 | Low - refactor | Behavior unchanged |
| Task 9 | None - verification only | N/A |

---

## Testing Strategy

1. Run existing spec tests after Tasks 1-2
2. Enable `economy_audit_mode` and verify ledger output matches expected values
3. Visual verification of resource bars after Task 4
4. Check logs for SetUnitTransferController registration message
5. Run timing comparison between ProcessEconomy and ResourceExcess modes with new tags
