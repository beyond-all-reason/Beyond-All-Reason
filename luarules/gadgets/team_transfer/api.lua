-- Team Transfer API - Clean public interface

local Api = {}

-- Include dependencies
local TeamTransfer = VFS.Include("LuaRules/Gadgets/team_transfer/definitions.lua")
local Pipeline = VFS.Include("LuaRules/Gadgets/team_transfer/pipeline.lua")
local Units = VFS.Include("LuaRules/Gadgets/team_transfer/units.lua")
local Resources = VFS.Include("LuaRules/Gadgets/team_transfer/resources.lua")

-- State for validators and listeners
local state = {
    unitValidators = {},
    resourceValidators = {},
    unitListeners = {},
    resourceListeners = {},
    lastRefusals = {},
}

-- === PUBLIC API ===

-- Registration functions
Api.RegisterUnitValidator = function(name, validatorFunc)
    state.unitValidators[name] = validatorFunc
end

Api.RegisterResourceValidator = function(name, validatorFunc)
    state.resourceValidators[name] = validatorFunc
end

Api.RegisterUnitListener = function(name, func)
    state.unitListeners[name] = func
end

Api.UnregisterUnitListener = function(name)
    state.unitListeners[name] = nil
end

Api.RegisterResourceListener = function(name, func)
    state.resourceListeners[name] = func
end

Api.UnregisterResourceListener = function(name)
    state.resourceListeners[name] = nil
end

-- Delegate to Pipeline
Api.RegisterResourceTransformPolicy = Pipeline.RegisterResourceTransformPolicy
Api.RegisterUnitTransformPolicy = Pipeline.RegisterUnitTransformPolicy

-- Main transfer functions (delegate to domain modules)
Api.TransferUnit = function(unitID, newTeam, reason)
    return Units.ProcessUnitTransfer(unitID, newTeam, reason)
end

Api.TransferResource = function(fromTeam, toTeam, resourceType, amount)
    local transferredAmount = Resources.ProcessResourceTransfer(fromTeam, toTeam, resourceType, amount, "api")
    if transferredAmount > 0 then
        Api.NotifyResourceTransfer(fromTeam, toTeam, resourceType, transferredAmount)
        return true
    end
    return false
end

-- Utility functions
Api.AddRefusal = function(team, msg)
    local frameNum = Spring.GetGameFrame()
    local lastRefusal = state.lastRefusals[team]
    if ((not lastRefusal) or (lastRefusal ~= frameNum)) then
        state.lastRefusals[team] = frameNum
        Spring.SendMessageToTeam(team, msg)
    end
end

-- Delegate to definitions
Api.IsTransferReason = TeamTransfer.IsTransferReason
Api.GetReasonName = TeamTransfer.GetReasonName
Api.IsValidTeam = TeamTransfer.IsValidTeam

-- === INTERNAL FUNCTIONS ===

-- Engine interface handlers (delegate to domain modules)
Api.NetResourceTransfer = Resources.NetResourceTransfer

-- Validation handlers
Api.ValidateUnitTransfer = function(unitID, unitDefID, oldTeam, newTeam, reason)
    for name, validator in pairs(state.unitValidators) do
        if not validator(unitID, unitDefID, oldTeam, newTeam, reason) then
            return false, name
        end
    end
    return true
end

Api.ValidateResourceTransfer = function(oldTeam, newTeam, resourceType, amount)
    for name, validator in pairs(state.resourceValidators) do
        if not validator(oldTeam, newTeam, resourceType, amount) then
            return false, name
        end
    end
    return true
end

-- Notification functions
Api.NotifyUnitTransfer = function(unitID, unitDefID, oldTeam, newTeam, reason)
    for _, func in pairs(state.unitListeners) do
        func(unitID, unitDefID, oldTeam, newTeam, reason)
    end
end

Api.NotifyResourceTransfer = function(oldTeam, newTeam, resourceType, amount)
    for _, func in pairs(state.resourceListeners) do
        func(oldTeam, newTeam, resourceType, amount)
    end
end

return Api
