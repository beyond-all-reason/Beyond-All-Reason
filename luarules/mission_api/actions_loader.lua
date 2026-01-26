local schema = VFS.Include('luarules/mission_api/actions_schema.lua')
local types = schema.Types
local parameters = schema.Parameters

--[[
	actionID = {
		type = actionTypes.EnableTrigger,
		parameters = {
			triggerID = 'triggerID'
		}
	}
]]

local actionsTypesNamingUnits = {
	[types.SpawnUnits] = true, [types.NameUnits] = true, }
local actionsTypesReferencingUnitNames = {
	[types.IssueOrders] = true, [types.UnnameUnits] = true, [types.TransferUnits] = true,
	[types.DespawnUnits] = true, [types.TransferUnits] = true, }

local function getAllActionIDsReferencedByTriggers()
	local allActionIDsReferencedByTriggers = {}
	for _, trigger in pairs(GG['MissionAPI'].Triggers) do
		if not table.isNilOrEmpty(trigger.actions) then
			for _, actionID in pairs(trigger.actions) do
				allActionIDsReferencedByTriggers[actionID] = true
			end
		end
	end
	return allActionIDsReferencedByTriggers
end

local function validateActions(actions)
	local allActionIDsReferencedByTriggers = getAllActionIDsReferencedByTriggers()

	for actionID, action in pairs(actions) do
		if not allActionIDsReferencedByTriggers[actionID] then
			Spring.Log('actions_loader.lua', LOG.WARNING, "[Mission API] Action not referenced by any trigger: " .. actionID)
		end

		validateParameters(parameters, action.type, action.parameters, 'Action', actionID)

		recordUnitNameCreationsAndReferences(actionsTypesNamingUnits, actionsTypesReferencingUnitNames, action, 'Action ' .. actionID)
	end
end

local function processRawActions(rawActions)
	local actions = table.map(rawActions, table.copy)
	validateActions(actions)
	return actions
end

return {
	ProcessRawActions = processRawActions,
}
