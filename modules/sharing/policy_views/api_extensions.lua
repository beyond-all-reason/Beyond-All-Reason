local PolicyEvaluation = VFS.Include("modules/sharing/policy_evaluation.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local UnitTransferAction = ModuleHandler.LoadActions("sharing").byName.unit_transfer

local API = {}

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
	API.NotifyHoverChangeListeners(newHoverTeamID, newHoverPlayerID)

	if newHoverTeamID and selectedUnits and #selectedUnits > 0 then
		local policyResult = PolicyEvaluation.GetUnitPolicyCached(myTeamID, newHoverTeamID, Spring)
		local validationResult = UnitTransferAction.validate(policyResult, selectedUnits, Spring)
		local invalidUnitIds = validationResult.invalidUnitIds
		if not policyResult.canShare and Spring.AreTeamsAllied(myTeamID, newHoverTeamID) then
			-- sharing fully disabled for this ally, so flag every selected unit for the hover highlight
			invalidUnitIds = selectedUnits
		end
		if #invalidUnitIds > 0 then
			API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, invalidUnitIds)
		else
			-- empty notify clears any previous invalid state
			API.NotifyHoverSelectedUnitsInvalid(newHoverTeamID, newHoverPlayerID, {})
		end
	else
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
