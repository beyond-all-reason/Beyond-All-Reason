# C++ Waterfill Solver

## Overview

This document describes the implementation of a C++ waterfill solver that correctly accounts for taxation during the binary search. The engine handles the expensive math while Lua provides per-member parameters.

**Key Insight**: The lift computation cannot be separated from tax logic because effective supply depends on tax. The engine must understand the piecewise tax model to find the correct balance point.

---

## Tax Model

For each sender, the effective contribution is:

```
effectiveSupply(grossDelta) = 
    min(grossDelta, allowance) +                      // tax-free portion
    max(0, grossDelta - allowance) * (1 - taxRate)    // taxed portion
```

Where:
- `allowance` = Lua-computed tax-free budget for this sender (e.g., `threshold - cumulativeSent`)
- `taxRate` = global tax rate (e.g., 0.15 = 15% tax)

This is a **piecewise linear function**. The engine implements this internally.

---

## API Design

### Lua Interface

Do not worry about game_resource_excess_controller. We will start testing with process_economy so game_resource_transfer_controller code path (PE) only.

```lua
-- Compute lift and deltas in one call
-- Returns: { lift = number, deltas = { [memberIdx] = deltaInfo, ... } }
local result = Spring.SolveWaterfill(members, taxRate)

-- Each member:
-- {
--   current = number,      -- current resource level
--   storage = number,      -- max storage capacity
--   shareTarget = number,  -- target fill level (from share slider)
--   allowance = number,    -- tax-free sending budget (Lua pre-computes)
-- }

-- Each deltaInfo in result.deltas:
-- {
--   gross = number,    -- raw delta before tax (negative = sender)
--   net = number,      -- effective delta after tax
--   taxed = number,    -- amount lost to tax
-- }
```

### Usage Example (ResourceExcess gadget)

```lua
function gadget:ResourceExcess(frame)
  local taxRate, thresholds = SharedConfig.getTaxConfig(Spring)
  
  -- Build member array per alliance
  for allyTeam, teams in pairs(allianceGroups) do
    local members = {}
    
    for i, teamId in ipairs(teams) do
      local team = teamData[teamId]
      local cumulativeSent = getCumulativeSent(teamId, resourceType)
      
      members[i] = {
        current = team.current + team.excess,
        storage = team.storage,
        shareTarget = team.storage * normalizeSlider(team.shareSlider),
        allowance = math.max(0, thresholds[resourceType] - cumulativeSent),
      }
    end
    
    -- Engine computes lift + deltas with tax-aware binary search
    local result = Spring.SolveWaterfill(members, taxRate)
    
    -- Lua applies results and tracks state
    for i, delta in pairs(result.deltas) do
      local teamId = teams[i]
      if delta.gross < 0 then
        -- Sender
        updateCumulativeSent(teamId, resourceType, -delta.gross)
        applyResourceChange(teamId, delta.gross)  -- deduct full amount
        logTransfer(teamId, delta.gross, delta.net, delta.taxed)
      else
        -- Receiver
        applyResourceChange(teamId, delta.net)  -- receive post-tax amount
      end
    end
  end
end
```

---

## What Engine Handles vs What Lua Handles

| Responsibility | Engine | Lua |
|----------------|--------|-----|
| Binary search for lift | Yes | No |
| Piecewise tax calculation | Yes | No |
| Balance equation (supply = demand) | Yes | No |
| Computing `allowance` per member | No | Yes (threshold - cumulativeSent) |
| Tracking cumulative sent | No | Yes |
| Applying SetTeamResource | No | Yes |
| Logging/auditing | No | Yes |
| Alliance grouping | No | Yes (calls per alliance) |

---

## C++ Implementation

### File Structure

```
rts/Sim/Economy/
├── WaterfillSolver.h
├── WaterfillSolver.cpp

rts/Lua/
└── LuaSyncedCtrl.cpp
```

### WaterfillSolver.h

```cpp
#pragma once

#include <vector>

namespace Economy {

struct WaterfillMember {
    float current;
    float storage;
    float shareTarget;
    float allowance;  // tax-free sending budget
};

struct WaterfillDelta {
    float gross;   // raw delta (negative = sender)
    float net;     // effective delta after tax
    float taxed;   // amount lost to tax
};

struct WaterfillResult {
    float lift;
    std::vector<WaterfillDelta> deltas;  // parallel to input members
};

class WaterfillSolver {
public:
    static constexpr float EPSILON = 1e-6f;
    static constexpr int LIFT_ITERATIONS = 40;
    
    WaterfillResult Solve(
        const std::vector<WaterfillMember>& members,
        float taxRate
    ) const;

private:
    // Compute effective supply from a sender at given target
    float EffectiveSupply(
        const WaterfillMember& m,
        float target,
        float taxRate
    ) const;
    
    // Compute demand needed by a receiver at given target
    float Demand(const WaterfillMember& m, float target) const;
    
    // Balance function: effectiveSupply - demand
    float Balance(
        const std::vector<WaterfillMember>& members,
        float lift,
        float taxRate
    ) const;
};

} // namespace Economy
```

### WaterfillSolver.cpp

```cpp
#include "WaterfillSolver.h"
#include <algorithm>
#include <cmath>

namespace Economy {

float WaterfillSolver::EffectiveSupply(
    const WaterfillMember& m,
    float target,
    float taxRate
) const {
    if (m.current <= target + EPSILON) {
        return 0.0f;  // not a sender
    }
    
    float grossDelta = m.current - target;
    
    // Piecewise tax: first 'allowance' units are tax-free
    float taxFree = std::min(grossDelta, m.allowance);
    float taxable = std::max(0.0f, grossDelta - m.allowance);
    float afterTax = taxable * (1.0f - taxRate);
    
    return taxFree + afterTax;
}

float WaterfillSolver::Demand(const WaterfillMember& m, float target) const {
    if (m.current >= target - EPSILON) {
        return 0.0f;  // not a receiver
    }
    return target - m.current;
}

float WaterfillSolver::Balance(
    const std::vector<WaterfillMember>& members,
    float lift,
    float taxRate
) const {
    float supply = 0.0f;
    float demand = 0.0f;
    
    for (const auto& m : members) {
        float target = std::min(m.shareTarget + lift, m.storage);
        supply += EffectiveSupply(m, target, taxRate);
        demand += Demand(m, target);
    }
    
    return supply - demand;
}

WaterfillResult WaterfillSolver::Solve(
    const std::vector<WaterfillMember>& members,
    float taxRate
) const {
    WaterfillResult result;
    result.deltas.resize(members.size());
    
    if (members.empty()) {
        result.lift = 0.0f;
        return result;
    }
    
    // Find max possible lift (headroom to storage)
    float maxLift = 0.0f;
    for (const auto& m : members) {
        float headroom = m.storage - m.shareTarget;
        maxLift = std::max(maxLift, headroom);
    }
    
    // Binary search for optimal lift where supply ≈ demand
    float lo = 0.0f;
    float hi = maxLift;
    
    for (int i = 0; i < LIFT_ITERATIONS; ++i) {
        float mid = 0.5f * (lo + hi);
        if (Balance(members, mid, taxRate) >= 0.0f) {
            lo = mid;  // supply >= demand, can raise water level
        } else {
            hi = mid;  // supply < demand, lower water level
        }
    }
    
    result.lift = lo;
    
    // Compute final deltas at this lift
    for (size_t i = 0; i < members.size(); ++i) {
        const auto& m = members[i];
        float target = std::min(m.shareTarget + result.lift, m.storage);
        
        WaterfillDelta& d = result.deltas[i];
        
        if (m.current > target + EPSILON) {
            // Sender
            d.gross = -(m.current - target);
            float grossSend = -d.gross;
            float taxFree = std::min(grossSend, m.allowance);
            float taxable = std::max(0.0f, grossSend - m.allowance);
            d.taxed = taxable * taxRate;
            d.net = -(taxFree + taxable - d.taxed);  // negative (outflow)
        } else if (m.current < target - EPSILON) {
            // Receiver
            d.gross = target - m.current;
            d.net = d.gross;  // receivers get post-tax amount
            d.taxed = 0.0f;
        } else {
            // Neutral
            d.gross = 0.0f;
            d.net = 0.0f;
            d.taxed = 0.0f;
        }
    }
    
    return result;
}

} // namespace Economy
```

### LuaSyncedCtrl.cpp Binding

```cpp
// Add to function table
{"SolveWaterfill", SolveWaterfill},

int LuaSyncedCtrl::SolveWaterfill(lua_State* L)
{
    if (!lua_istable(L, 1)) {
        luaL_error(L, "SolveWaterfill: expected table of members");
        return 0;
    }
    
    float taxRate = luaL_checknumber(L, 2);
    
    // Parse members
    std::vector<Economy::WaterfillMember> members;
    
    for (lua_pushnil(L); lua_next(L, 1) != 0; lua_pop(L, 1)) {
        if (!lua_istable(L, -1)) continue;
        
        Economy::WaterfillMember m;
        
        lua_getfield(L, -1, "current");
        m.current = luaL_checknumber(L, -1);
        lua_pop(L, 1);
        
        lua_getfield(L, -1, "storage");
        m.storage = luaL_checknumber(L, -1);
        lua_pop(L, 1);
        
        lua_getfield(L, -1, "shareTarget");
        m.shareTarget = luaL_checknumber(L, -1);
        lua_pop(L, 1);
        
        lua_getfield(L, -1, "allowance");
        m.allowance = luaL_optnumber(L, -1, 0.0f);  // default: no tax-free allowance
        lua_pop(L, 1);
        
        members.push_back(m);
    }
    
    // Solve
    Economy::WaterfillSolver solver;
    auto result = solver.Solve(members, taxRate);
    
    // Build result table
    lua_newtable(L);
    
    // result.lift
    lua_pushnumber(L, result.lift);
    lua_setfield(L, -2, "lift");
    
    // result.deltas
    lua_newtable(L);
    for (size_t i = 0; i < result.deltas.size(); ++i) {
        const auto& d = result.deltas[i];
        
        // Skip neutral members
        if (std::abs(d.gross) < Economy::WaterfillSolver::EPSILON) {
            continue;
        }
        
        lua_newtable(L);
        lua_pushnumber(L, d.gross);
        lua_setfield(L, -2, "gross");
        lua_pushnumber(L, d.net);
        lua_setfield(L, -2, "net");
        lua_pushnumber(L, d.taxed);
        lua_setfield(L, -2, "taxed");
        
        lua_rawseti(L, -2, static_cast<int>(i) + 1);  // Lua 1-indexed
    }
    lua_setfield(L, -2, "deltas");
    
    return 1;
}
```

-
Implement the solver in C++.

**Files**:
- `rts/Sim/Economy/WaterfillSolver.h` (new)
- `rts/Sim/Economy/WaterfillSolver.cpp` (new)
- `rts/Lua/LuaSyncedCtrl.cpp` (add binding)
- `rts/Lua/LuaSyncedCtrl.h` (declare function)

**Validation**: Unit tests in C++ comparing against expected outputs

Add modrules option and conditional dispatch in Lua.

**Files**:
- `gamedata/modrules.lua` - Add `use_cpp_waterfill = true`
- `rts/Sim/Misc/ModInfo.cpp` - Parse option
- `economy_waterfill_solver.lua` - Add `if useCppSolver then Spring.SolveWaterfill(...) else ...`

**Validation**: Economy audit dashboard shows identical results for both paths


## Expected Performance Impact

| Component | Lua | C++ | Speedup |
|-----------|-----|-----|---------|
| Lift binary search (40 iters × N members) | ~300μs | ~15μs | 20x |
| Delta computation | ~50μs | ~3μs | 15x |
| Lua↔C++ marshaling | N/A | ~15μs | - |
| **Total solver time** | ~350μs | ~33μs | **10x** |

The game retains full control of policy (cumulative tracking, logging, application) while the expensive math runs in native code.

---

## Generality for Other Games

Games without BAR's tax system can:
- Set `taxRate = 0` for no taxation
- Set `allowance = 0` for all members to tax all contributions
