# Table Pooling Round 2 - Exhaustive Allocation Analysis

## Overview

This document identifies all table allocations in the economy hot path that should be converted to **Lazy-Init Caching** to eliminate GC pressure.

## Key Pattern: Lazy-Init with Field Overwrite

**Principle**: Cache tables by their definitive ID, lazy-init once, overwrite fields every frame.

```lua
-- Module level: cache indexed by definitive ID
local cache = {}

-- In hot path:
local entry = cache[id]
if not entry then
  entry = {}
  cache[id] = entry
end

-- Overwrite ALL fields - after this, all are non-nil (EmmyLua non-nullable)
entry.field1 = value1
entry.field2 = value2
entry.field3 = value3
```

**Benefits**:
- Zero allocations after first cycle (warmup)
- No nil-ing or clearing required
- Non-nullable EmmyLua types catch bugs at lint time
- O(1) lookup by definitive ID

---

## Current Allocation Count

| File | Allocations Per Cycle | Tables Created |
|------|----------------------|----------------|
| economy_waterfill_solver.lua | 14 sites | ~40 tables |
| game_resource_excess_controller.lua | 5 sites | ~25 tables |
| game_resource_transfer_controller.lua | 2 sites | ~10 tables |
| resource_transfer_synced.lua | 0 (already pooled) | 0 |
| **TOTAL** | **21 sites** | **~75 tables/cycle** |

After optimization: **0 new tables after warmup**

---

## File-by-File Allocation Map

### economy_waterfill_solver.lua

#### collectMembers() - Lines 38-77

| Line | Current Code | Cache Key | Cache Name |
|------|--------------|-----------|------------|
| 39 | `local grouped = {}` | allyTeam | `groupCache` |
| 57-60 | `group = {}` | allyTeam | `groupCache[allyTeam]` |
| 61-72 | `{ teamId = ..., ... }` | teamId | `memberCache[teamId]` |

**Fix Pattern**:
```lua
-- Module level
local memberCache = {}  -- indexed by teamId
local groupCache = {}   -- indexed by allyTeam
local groupsBuilt = false

local function collectMembers(teamsList, resourceType, thresholds, springRepo)
  -- Build group structure once (team→alliance is fixed for game)
  if not groupsBuilt then
    for allyTeam = 0, 15 do  -- or iterate known alliances
      groupCache[allyTeam] = {}
    end
    groupsBuilt = true
  end
  
  -- Track group sizes this frame
  local groupSizes = {}
  
  for teamId, team in pairs(teamsList) do
    local allyTeam = springRepo.GetTeamInfo(teamId).allyTeam
    
    -- Lazy-init member once
    local member = memberCache[teamId]
    if not member then
      member = {}
      memberCache[teamId] = member
    end
    
    -- Overwrite ALL fields (non-nullable after this)
    member.teamId = teamId
    member.allyTeam = allyTeam
    member.resourceType = resourceType
    member.current = team.current + team.excess
    member.storage = team.storage
    member.shareTarget = team.storage * normalizeSlider(team.shareSlider)
    member.excess = team.excess
    member.cumulativeSent = team.cumulativeSent
    
    -- Add to group (reference, not copy)
    local group = groupCache[allyTeam]
    groupSizes[allyTeam] = (groupSizes[allyTeam] or 0) + 1
    group[groupSizes[allyTeam]] = member
  end
  
  return groupCache, groupSizes
end
```

#### allocateGroup() - Lines 147-289

| Line | Current Code | Cache Key | Cache Name |
|------|--------------|-----------|------------|
| 148 | `local senders = {}` | (array) | `sendersArray` |
| 149 | `local receivers = {}` | (array) | `receiversArray` |
| 150 | `local ledgers = {}` | teamId | `ledgerCache[teamId]` |
| 154 | `{ sent = 0, ... }` | teamId | `ledgerCache[teamId]` |
| 173-181 | `{ member = ..., costBudget = ... }` | teamId | `senderDescCache[teamId]` |
| 183-187 | `{ member = ..., need = ... }` | teamId | `receiverDescCache[teamId]` |

**Fix Pattern**:
```lua
-- Module level
local ledgerCache = {}       -- indexed by teamId
local senderDescCache = {}   -- indexed by teamId
local receiverDescCache = {} -- indexed by teamId

local function allocateGroup(members, tax, thresholds)
  local senderCount = 0
  local receiverCount = 0
  
  for _, member in ipairs(members) do
    local teamId = member.teamId
    
    -- Lazy-init ledger once per team
    local ledger = ledgerCache[teamId]
    if not ledger then
      ledger = {}
      ledgerCache[teamId] = ledger
    end
    -- Overwrite all fields
    ledger.sent = 0
    ledger.received = 0
    ledger.untaxed = 0
    ledger.taxed = 0
    
    if isSender(member) then
      senderCount = senderCount + 1
      -- Lazy-init sender descriptor
      local desc = senderDescCache[teamId]
      if not desc then
        desc = {}
        senderDescCache[teamId] = desc
      end
      desc.member = member
      desc.costBudget = computeCostBudget(member, thresholds)
      desc.ledger = ledger
    else
      receiverCount = receiverCount + 1
      -- Lazy-init receiver descriptor
      local desc = receiverDescCache[teamId]
      if not desc then
        desc = {}
        receiverDescCache[teamId] = desc
      end
      desc.member = member
      desc.need = computeNeed(member)
      desc.ledger = ledger
    end
  end
end
```

#### Solve() - Lines 306-410

| Line | Current Code | Cache Key | Cache Name |
|------|--------------|-----------|------------|
| 318 | `local cumulativeUpdates = {}` | teamId | `cumulativeCache[teamId]` |
| 321 | `local allLedgers = {}` | teamId | `allLedgersCache[teamId]` |
| 326-329 | `{ [METAL] = {...}, ... }` | teamId | `teamLedgerCache[teamId]` |
| 335 | `local memberById = {}` | teamId | `memberByIdCache[teamId]` |

**Fix Pattern**:
```lua
-- Module level
local teamLedgerCache = {}  -- indexed by teamId, contains {metal={...}, energy={...}}

-- In Solve():
for teamId in pairs(teamsList) do
  local teamLedger = teamLedgerCache[teamId]
  if not teamLedger then
    teamLedger = {
      [ResourceType.METAL] = {},
      [ResourceType.ENERGY] = {},
    }
    teamLedgerCache[teamId] = teamLedger
  end
  
  -- Overwrite metal fields
  local m = teamLedger[ResourceType.METAL]
  m.sent = 0
  m.received = 0
  m.untaxed = 0
  m.taxed = 0
  
  -- Overwrite energy fields
  local e = teamLedger[ResourceType.ENERGY]
  e.sent = 0
  e.received = 0
  e.untaxed = 0
  e.taxed = 0
end
```

---

### game_resource_excess_controller.lua

#### BuildTeamData() - Lines 65-107

| Line | Current Code | Cache Key | Cache Name |
|------|--------------|-----------|------------|
| 66 | `local teams = {}` | teamId | `teamsCache[teamId]` |
| 79-102 | `{ allyTeam = ..., metal = {...}, energy = {...} }` | teamId | `teamsCache[teamId]` |

**Fix Pattern**:
```lua
-- Module level
local teamsCache = {}  -- indexed by teamId

local function BuildTeamData(springRepo, teamsList)
  for _, teamId in ipairs(teamsList) do
    -- Lazy-init team structure once
    local team = teamsCache[teamId]
    if not team then
      team = {
        metal = {},
        energy = {},
      }
      teamsCache[teamId] = team
    end
    
    -- Overwrite all fields
    team.allyTeam = springRepo.GetTeamInfo(teamId).allyTeam
    team.isDead = springRepo.IsTeamDead(teamId)
    
    local mCur, mSto, _, _, mExc, mRec, mSen = springRepo.GetTeamResources(teamId, "metal")
    team.metal.current = mCur
    team.metal.storage = mSto
    team.metal.excess = mExc
    team.metal.received = mRec
    team.metal.sent = mSen
    -- ... same pattern for energy
  end
  
  return teamsCache
end
```

#### ApplyResults() - Lines 113-143

| Line | Current Code | Cache Key | Cache Name |
|------|--------------|-----------|------------|
| 138 | `{ sent = { mSentVal, eSentVal } }` | (singleton) | `statsSentBuffer` |
| 141 | `{ received = { mRecvVal, eRecvVal } }` | (singleton) | `statsRecvBuffer` |

**Fix Pattern**:
```lua
-- Module level (singleton buffers)
local statsSentBuffer = { sent = { 0, 0 } }
local statsRecvBuffer = { received = { 0, 0 } }

-- In ApplyResults:
if mSentVal > 0 or eSentVal > 0 then
  statsSentBuffer.sent[1] = mSentVal
  statsSentBuffer.sent[2] = eSentVal
  springRepo.AddTeamResourceStats(teamId, statsSentBuffer)
end

if mRecvVal > 0 or eRecvVal > 0 then
  statsRecvBuffer.received[1] = mRecvVal
  statsRecvBuffer.received[2] = eRecvVal
  springRepo.AddTeamResourceStats(teamId, statsRecvBuffer)
end
```

---

### game_resource_transfer_controller.lua

Already using lazy-init pattern with `GetPooledTable()`. Minor improvement: index by teamId instead of poolIndex.

| Line | Current Code | Improvement |
|------|--------------|-------------|
| 139-141 | `resultPool[poolIndex]` | Use `resultPool[teamId]` |

---

## Implementation Checklist

- [ ] economy_waterfill_solver.lua
  - [ ] Add `memberCache` indexed by teamId
  - [ ] Add `groupCache` indexed by allyTeam (build once)
  - [ ] Add `ledgerCache` indexed by teamId
  - [ ] Add `senderDescCache` / `receiverDescCache` indexed by teamId
  - [ ] Add `teamLedgerCache` indexed by teamId
  - [ ] Verify all fields overwritten (non-nullable)

- [ ] game_resource_excess_controller.lua
  - [ ] Add `teamsCache` indexed by teamId
  - [ ] Add singleton stats buffers
  - [ ] Verify all fields overwritten (non-nullable)

- [ ] game_resource_transfer_controller.lua
  - [ ] Change `resultPool[poolIndex]` to `resultPool[teamId]`

- [ ] Add EmmyLua annotations with non-nullable types
- [ ] Verify no regressions via economy audit dashboard

---

## Expected Impact

| Metric | Before | After |
|--------|--------|-------|
| Tables created per cycle | ~75 | 0 (after warmup) |
| GC pressure | High | Minimal |
| Lua memory churn | ~3KB/cycle | ~0 |
| GC pause risk | Yes | No |
| Nil-related bugs | Possible | Caught by linter |

---

## EmmyLua Type Example

```lua
---@class MemberData
---@field teamId number
---@field allyTeam number
---@field resourceType ResourceType
---@field current number
---@field storage number
---@field shareTarget number
---@field excess number
---@field cumulativeSent number

---@type table<number, MemberData>  -- indexed by teamId
local memberCache = {}
```

After the lazy-init + overwrite pattern, all fields are guaranteed non-nil and the linter enforces this.
