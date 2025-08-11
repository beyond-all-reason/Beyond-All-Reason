-- Team Transfer Manager - All state and logic for transfers

local Manager = {}

-- Include utilities
local TeamTransfer = VFS.Include("LuaRules/Gadgets/team_transfer/definitions.lua")
local Units = VFS.Include("LuaRules/Gadgets/team_transfer/units.lua")
local Resources = VFS.Include("LuaRules/Gadgets/team_transfer/resources.lua")

-- State management
local state = {
    unitValidators = {},
    resourceValidators = {},
    unitListeners = {},
    resourceListeners = {},
    lastRefusals = {},
}

-- Unit validation
Manager.RegisterUnitValidator = function(name, validatorFunc)
    state.unitValidators[name] = validatorFunc
end

Manager.ValidateUnitTransfer = function(unitID, unitDefID, oldTeam, newTeam, reason)
    for name, validator in pairs(state.unitValidators) do
        if not validator(unitID, unitDefID, oldTeam, newTeam, reason) then
            return false, name
        end
    end
    return true
end

-- Resource validation
Manager.RegisterResourceValidator = function(name, validatorFunc)
    state.resourceValidators[name] = validatorFunc
end

Manager.ValidateResourceTransfer = function(oldTeam, newTeam, resourceType, amount)
    for name, validator in pairs(state.resourceValidators) do
        if not validator(oldTeam, newTeam, resourceType, amount) then
            return false, name
        end
    end
    return true
end

-- Unit listeners
Manager.RegisterUnitListener = function(name, func)
    state.unitListeners[name] = func
end

Manager.UnregisterUnitListener = function(name)
    state.unitListeners[name] = nil
end

Manager.NotifyUnitTransfer = function(unitID, unitDefID, oldTeam, newTeam, reason)
    for _, func in pairs(state.unitListeners) do
        func(unitID, unitDefID, oldTeam, newTeam, reason)
    end
end

-- Resource listeners
Manager.RegisterResourceListener = function(name, func)
    state.resourceListeners[name] = func
end

Manager.UnregisterResourceListener = function(name)
    state.resourceListeners[name] = nil
end

Manager.NotifyResourceTransfer = function(oldTeam, newTeam, resourceType, amount)
    for _, func in pairs(state.resourceListeners) do
        func(oldTeam, newTeam, resourceType, amount)
    end
end

-- Refusal throttling
Manager.AddRefusal = function(team, msg)
    local frameNum = Spring.GetGameFrame()
    local lastRefusal = state.lastRefusals[team]
    if ((not lastRefusal) or (lastRefusal ~= frameNum)) then
        state.lastRefusals[team] = frameNum
        Spring.SendMessageToTeam(team, msg)
    end
end

-- Transfer functions (delegate to domain modules)
Manager.TransferUnit = function(unitID, newTeam, reason)
    return Units.TransferUnit(unitID, newTeam, reason)
end

Manager.TransferResource = function(fromTeam, toTeam, resourceType, amount)
    return Resources.TransferResource(fromTeam, toTeam, resourceType, amount)
end


return Manager
