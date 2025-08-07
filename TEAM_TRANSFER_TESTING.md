# Team Transfer System Testing Matrix

## Overview
This document outlines the testing approach for the team transfer system across 3 different system states.

## System States

### State 1: Updated (Engine + Game Updated)
- **Engine**: Uses deprecated C++ enum but calls `SyncedActionFallback` to Lua
- **Game**: Uses new `TeamTransfer` service with full Lua handlers
- **Expected**: All transfers handled by Lua, C++ fallbacks never triggered

### State 2: Fallbacks (Game Not Updated, Engine Updated) 
- **Engine**: Uses deprecated C++ enum, calls `SyncedActionFallback` but falls back to C++
- **Game**: Uses old `GG.CHANGETEAM_REASON` enum (commented out), no Lua handlers
- **Expected**: C++ fallback logic handles transfers (backward compatibility)

### State 3: Future (Engine Deprecation Applied)
- **Engine**: C++ enum and fallbacks completely removed  
- **Game**: Must use new `TeamTransfer` service
- **Expected**: Pure Lua implementation, no C++ involvement

## Test Matrix

| Action Type | Engine Call Point | State 1 Behavior | State 2 Behavior | State 3 Behavior |
|-------------|-------------------|-------------------|-------------------|-------------------|
| **Builder Capture** | `BuilderCapture` SyncedActionFallback | ✅ `builder_capture.lua` handler | ⚠️ C++ fallback in `Builder.cpp:522-525` | ✅ Pure Lua (required) |
| **Team Give Everything** | `TeamGiveEverything` SyncedActionFallback | ✅ `team_transfer.lua` main handler | ⚠️ C++ fallback in `Team.cpp:251-254` | ✅ Pure Lua (required) |
| **Network Share** | `NetShareTransfer` SyncedActionFallback | ✅ `network_share.lua` handler | ⚠️ C++ fallback in `NetCommands.cpp:955-958,1101-1104` | ✅ Pure Lua (required) |
| **Direct Capture** | Direct `ChangeTeam()` call | ✅ `team_transfer.lua` CAPTURED handler | ⚠️ C++ logic in `Unit.cpp:1541,1605` | ✅ Must implement `AllowUnitTransfer` callin |
| **Take Command** | Lua command trigger | ✅ `take_command.lua` handler | ❌ Not implemented in State 2 | ✅ Pure Lua (existing) |
| **Market Sales** | Lua trigger | ✅ `team_transfer.lua` SOLD handler | ❌ Not implemented in State 2 | ✅ Pure Lua (existing) |

## Testing Scenarios

### Core Transfer Validation
1. **Builder Capture**
   - Enemy builder captures unit
   - Validate ally/enemy checks
   - Test capture distance limits
   
2. **Team Transfers**  
   - `/give` command between allies
   - Team elimination transfers
   - Network share transfers

3. **Take Commands**
   - `/take` from idle ally 
   - `/take` validation (no human players)
   - `/take` from enemy (should fail)

### Backward Compatibility
1. **State 2 Fallback Testing**
   - Verify C++ fallbacks work when Lua handlers absent
   - Test all engine `SyncedActionFallback` calls revert to C++
   - Validate old enum values still work

2. **Migration Testing**
   - Test mixed State 1/State 2 multiplayer scenarios
   - Verify no desyncs between different client versions

### Future Proofing  
1. **State 3 Pure Lua**
   - Test complete removal of C++ enum
   - Verify all transfers work through Lua only
   - Performance testing of pure Lua implementation

## Key Test Cases

### Multi-State Compatibility
```lua
-- Test that handles all 3 states
function TestBuilderCapture()
    local unitID = CreateTestUnit()
    local oldTeam, newTeam = 0, 1
    
    -- State 1: Should call our handler
    assert(GG.TeamTransfer.HandleTransfer(unitID, oldTeam, newTeam, 
           GG.TeamTransfer.REASON.CAPTURED, "BuilderCapture"))
    
    -- State 2: Should work via C++ fallback if handler absent
    -- State 3: Should work via pure Lua (no C++ available)
end
```

### Performance Validation
- Measure transfer latency in each state
- Validate no performance regression from C++ → Lua
- Test high-frequency transfer scenarios (large team eliminations)

### Error Handling
- Test malformed transfer requests
- Validate proper fallback when handlers return false
- Test edge cases (invalid teams, dead units, etc.)

## Success Criteria

### State 1 (Current Target)
- ✅ All C++ `SyncedActionFallback` calls reach Lua handlers
- ✅ Individual handler files work correctly  
- ✅ Main switch in `team_transfer.lua` delegates properly
- ✅ Backward compatibility maintained via C++ fallbacks

### State 2 (Compatibility)
- ✅ System works without new Lua handlers
- ✅ C++ fallbacks handle all transfer scenarios
- ✅ No breaking changes for existing games

### State 3 (Future)
- ✅ Pure Lua implementation handles all scenarios
- ✅ Performance equivalent to C++ implementation
- ✅ Complete elimination of C++ enum dependency

## Implementation Notes

The key insight is that we're following `ChangeTeamReasonCpp` usage as a code smell - anywhere the engine uses this enum indicates logic that should move to Lua. The current implementation provides:

1. **Authoritative Lua enum** in `TeamTransfer.REASON`
2. **Modular handler system** with individual files per action type  
3. **Central switch/service** in `team_transfer.lua`
4. **Engine integration** via `SyncedActionFallback` handlers
5. **Graceful degradation** to C++ fallbacks when Lua handlers unavailable

This architecture allows the engine to become more framework-like while games implement domain-specific transfer logic in Lua.