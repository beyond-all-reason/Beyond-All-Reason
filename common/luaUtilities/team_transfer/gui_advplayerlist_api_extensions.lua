local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local API = {}

-- Hover listener management
local hoverChangeListeners = {}

---@param listener function
function API.AddHoverChangeListener(listener)
    table.insert(hoverChangeListeners, listener)
end

---@param listener function
function API.RemoveHoverChangeListener(listener)
    for i, existingListener in ipairs(hoverChangeListeners) do
        if existingListener == listener then
            table.remove(hoverChangeListeners, i)
            break
        end
    end
end

---Handle hover changes and notify about invalid units for the hovered player
---@param myTeamID number
---@param selectedUnits number[]
---@param newHoverTeamID number | nil
---@param newHoverPlayerID number | nil
function API.HandleHoverChange(myTeamID, selectedUnits, newHoverTeamID, newHoverPlayerID)
    -- Notify hover change listeners
    API.NotifyHoverChangeListeners(newHoverTeamID, newHoverPlayerID)

    -- Notify about invalid units (or clear them if not hovering)
    if newHoverTeamID and selectedUnits and #selectedUnits > 0 then
        local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, newHoverTeamID)
        local validationResult = UnitShared.ValidateUnits(policyResult, selectedUnits)
        if #validationResult.invalidUnitIds > 0 then
            API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, validationResult.invalidUnitIds)
        else
            -- No invalid units, but still notify to clear any previous invalid state
            API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, {})
        end
    else
        -- Not hovering or no selected units, clear invalid state
        API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, {})
    end
end

---@param newHoverTeamID number | nil
---@param newHoverPlayerID number | nil
function API.NotifyHoverChangeListeners(newHoverTeamID, newHoverPlayerID)
    for _, listener in ipairs(hoverChangeListeners) do
        listener(newHoverTeamID, newHoverPlayerID)
    end
end

-- Hover invalid units listeners
local hoverInvalidUnitsListeners = {}

---@param listener function
function API.AddHoverInvalidUnitsListener(listener)
    table.insert(hoverInvalidUnitsListeners, listener)
end

---@param listener function
function API.RemoveHoverInvalidUnitsListener(listener)
    for i, existingListener in ipairs(hoverInvalidUnitsListeners) do
        if existingListener == listener then
            table.remove(hoverInvalidUnitsListeners, i)
            break
        end
    end
end

---@param newHoverTeamID number | nil
---@param newHoverPlayerID number | nil
---@param invalidUnitIds number[]
function API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, invalidUnitIds)
    for _, listener in ipairs(hoverInvalidUnitsListeners) do
        listener(newHoverTeamID, newHoverPlayerID, invalidUnitIds)
    end
end

return API
