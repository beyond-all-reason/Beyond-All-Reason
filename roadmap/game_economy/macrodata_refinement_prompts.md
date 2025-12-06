# Macrodata Refinement Prompts

This document contains the original user requirements that generated the plan.

---

## Original Request (Part 1)

> 1) @Beyond-All-Reason/types/spring.lua:77-79 eh I really think this should be a different contract. If we're going to bother with a ledger and tracking this stuff. That is INTERNAL to the module and the engine doesn't care about that. If ResourceData as a type is really coming from the engine, then we should remove these fields and put them on the ledger, since they do NOT roundtrip. That said, i think tracking per-team transfers are probably TOO much gc table thrash, so that's probably unnecessary. The second return value here is mostly for auditing/logging and is largely optional, so we should optimize that for performance (which speaks to (3) - which I only think would be elegant if we DID need to audit per-team resource transfer allocations?)
>
> 2) @Beyond-All-Reason/common/luaUtilities/economy/bar_economy_waterfill_solver.lua:345 We already have this concept of "EconomyFlowLedger". I don't think we need these types on ResourceData. That should be the engine -> game contract. And defines the result. But we want to hide that from the engine since it doesn't care it just sets the new team values.
>
> 2) Quick check, (and this doesn't need to go in the plan unless you think it makes sense) would it be possible to elegantly re-use this type @Beyond-All-Reason/types/team_transfer.lua:74-82 and maybe the logic within the waterfill solver - or would it be more pragamatic to have a bespoke type that is owned by the waterfill solver?
>
> 3) Another problem I'd like you tackle is finding the place in the engine that currently renders "current"/the energy and metal resource visual slider values. We want to cap current display value to Math.min(current, storage) during game_economy=1 because we KNOW the game will handle it next frame and don't want to show things we know to be impossible between frame. (This one thing should render tracking "excess" separately between frames as unnecessary?)
>
> 4) @Beyond-All-Reason/luarules/gadgets/game_unit_transfer_controller.lua:116 This needs to implement SetUnitTransferController, which is in Recoil but not this controller.

---

## Original Request (Part 2)

> 5) @Beyond-All-Reason/luarules/gadgets/game_resource_excess_controller.lua:63-79 this should be cast into @Beyond-All-Reason/luarules/gadgets/game_resource_transfer_controller.lua:160 `ResourceData[]` explicitly.
>
> 6) Ensure our Stopwatch timings are consistent for "tags" between these two modes. Ideally the timeline graph in the bottom right of the image I showed you "Time" has distinct lines for "PreMunge" which is CPP Munge, whch should show more time for ProcessEconomy in C++, whereas we also want a distinct "LuaMunge" (maybe we just call it that, CppMunge and LuaMuge?) that Excess SHOULD take more time in generating its facsimile table. Then we want CppSetters and LuaSetters values. Maybe just "Setters", but ProcessEconomy's setters need to drift back into CPP if we compare them apples to apples - in which case we should do the same thing by combining it back into "PreMunge/PostMunge" (I guess this makes the most sense, note the difference between the categories with a key if we go that route)
>
> @Beyond-All-Reason/roadmap/game_economy/macrodata_refinement_plan.md:19-21 Nah this is incorrect. The engine receives back ResourceData and flatly sets team resources to what we say. That is the semantic clarity here. Those go to our ledger/second return value from WaterFill.ProcessEconomy (let's make a task (7) rename this function to Solve @Beyond-All-Reason/common/luaUtilities/economy/bar_economy_waterfill_solver.lua:346 and this function maybe WaterfillSolve, that was we remove ambiguity with ProcessEconomy, which can refer to the engine -> game function. We still want to maintain parity between their parameters.
>
> (8) feel free to reuse @Beyond-All-Reason/common/luaUtilities/team_transfer/resource_transfer_synced.lua:206-213 parts of resource_transfer_synced that are relevant, like updating cumulative here.

---

## Attached Context

### spring.lua:77-79 (Original fields to remove)
```lua
---@field sent number? resources sent this frame
---@field received number? resources received this frame
---@field excess number? excess dumped this frame
```

### team_transfer.lua:74-82
```lua
---@class ResourceTransferResult
---@field success boolean
---@field sent number
---@field received number
---@field untaxed number
---@field senderTeamId number
---@field receiverTeamId number
---@field policyResult ResourcePolicyResult
```

### bar_economy_waterfill_solver.lua:273-285 (mutation of resource.sent/received)
```lua
local newCurrent = member.current - sender.costSpent
if newCurrent < 0 then
  newCurrent = 0
end
resource.current = newCurrent
resource.sent = sender.costSpent
resource.received = 0
local allowance = member.remainingTaxFreeAllowance - sender.untaxedDelivered
member.remainingTaxFreeAllowance = allowance > 0 and allowance or 0
member.cumulativeSent = member.cumulativeSent + sender.costSpent
ledgers[member.teamId].sent = sender.costSpent
ledgers[member.teamId].untaxed = sender.untaxedDelivered
ledgers[member.teamId].taxed = sender.taxedDelivered
```

### bar_economy_waterfill_solver.lua:345-346
```lua
---@return EconomyFlowSummary
function Gadgets.ProcessEconomy(springRepo, teamsList, frame)
```

### game_resource_excess_controller.lua:63-79 (inline team data)
```lua
teams[#teams + 1] = {
    id = teamID,
    allyTeam = allyTeam,
    metal = {
        current = metalWithExcess,
        storage = mSto or 1000,
        shareSlider = mShare or 0.99,
        excess = metalExcess,
    },
    energy = {
        current = energyWithExcess,
        storage = eSto or 1000,
        shareSlider = eShare or 0.95,
        excess = energyExcess,
    }
}
```

### game_resource_transfer_controller.lua:160
```lua
---@param teams TeamResourceData[]
```

### resource_transfer_synced.lua:206-213 (cumulative tracking)
```lua
---@param ctx ResourceTransferContext
---@param transferResult ResourceTransferResult
function Gadgets.RegisterPostTransfer(ctx, transferResult)
  local cumulativeParam = Shared.GetCumulativeParam(ctx.resourceType)
  local cumulativeSent = tonumber(ctx.springRepo.GetTeamRulesParam(transferResult.senderTeamId, cumulativeParam))
  ctx.springRepo.SetTeamRulesParam(ctx.senderTeamId, cumulativeParam, cumulativeSent + transferResult.sent)
end
```

---

## Key Engine Files Discovered

### ResourceBar.cpp (spring/rts/Game/UI/ResourceBar.cpp)

Lines 105-117 - where resource bar display ratios are calculated:
```cpp
const float sx[] = {
  (rcs.metal != 0.0f)? ((rcr.metal / rcs.metal) * metalbarlen): 0.0f,
  rshr.metal * metalbarlen
};
```

This needs to be capped when `modInfo.game_economy` is enabled.

### LuaSyncedCtrl.cpp:1866-1904 - SetUnitTransferController

Already implemented and called by game_unit_transfer_controller.lua.

---

## Corrections Applied

**Correction 1 - Engine does not parse stats from return:**
> Original: The engine parses `sent`, `received`, `excess` for stats tracking
> 
> Corrected: The engine receives back ResourceData and sets all provided fields. The `sent`, `received`, `excess` fields go to the internal ledger for auditing. Stats tracking is handled via `Spring.AddTeamResourceStats` calls in Lua.

**Correction 2 - Full ResourceData returned, not just current:**
> Original: The output contract is just `{ current: number }` per resource
>
> Corrected: The output contract is full `ResourceData[]`. The engine will set every value passed back, even though our implementation only modifies `current`. The Excess mode can return minimal data (just `current`) since it uses SetTeamResource directly.

---

## Timing Analysis Context

The user provided a timing analysis graph showing:
- **Lift Over Time**: Metal (flat ~50) vs Energy (oscillating 300-700)
- **Supply - Demand Balance**: Metal flat, Energy high positive balance
- **Total Sent/Received**: Only energy has significant flow
- **Solver Timing**: Multiple metrics including PreMunge, Solver, PostMunge, PolicyCache, CppMunge, LuaTotal, CppSetters

Goal: Align timing tags so ProcessEconomy (C++ data prep) vs ResourceExcess (Lua data prep) can be compared fairly:
- `CppMunge` (C++ side) vs `LuaMunge` (Lua side) for data preparation
- `Solver` for algorithm time
- `PostMunge` for result building
