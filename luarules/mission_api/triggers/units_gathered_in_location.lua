local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local matchingUnits = GG['MissionAPI'].Modules.UnitQuery.MatchingUnits

---@class Gathering
---@field unitIDs table<integer, true> the team's units inside the area
---@field changed boolean
---@field fired boolean

---@return Gathering
local function getGathering(context, triggerID)
	local gathering = context.Gatherings[triggerID]
	if not gathering then
		gathering = { unitIDs = {}, changed = false, fired = false } ---@type Gathering
		context.Gatherings[triggerID] = gathering
	end
	return gathering
end

-- A dead, captured or given away unit has left the group, and one still being built cannot walk in.
---@return boolean
local function isGathered(parameters, unitIDsInside)
	local anyWaitedFor = false
	for _, unitID in ipairs(matchingUnits(parameters.unitName, nil, parameters.teamID)) do
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			if not unitIDsInside[unitID] then
				return false
			end
			anyWaitedFor = true
		end
	end
	return anyWaitedFor
end

local function markChanged(context, triggerID)
	local gathering = context.Gatherings[triggerID]
	if gathering then
		gathering.changed = true
	end
end

-- Fires once when every unit named unitName on teamID is inside the area, and again only after
-- one has left and they are all back.
return {
	type = 'UnitsGatheredInLocation',
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }
		{ name = 'area',     required = true, type = ParameterTypes.Area },
		{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
		{ name = 'teamID',   required = true, type = ParameterTypes.TeamID },
	},
	callins = {
		-- The group is looked at only on a frame after something changed. A trigger refused while they
		-- are gathered (inactive, prerequisites, stage) asks again each frame until it fires or they part.
		GameFrame = function(trigger, triggerID, context)
			local gathering = context.Gatherings[triggerID]
			if not gathering or not gathering.changed then
				return
			end

			if not isGathered(trigger.parameters, gathering.unitIDs) then
				gathering.fired = false
				gathering.changed = false
			elseif not gathering.fired then
				gathering.fired = context.ActivateTrigger(trigger)
				gathering.changed = not gathering.fired
			else
				gathering.changed = false
			end
		end,
		UnitsEnteredArea = function(trigger, triggerID, context, unitIDs)
			local gathering = getGathering(context, triggerID)
			for i = 1, #unitIDs do
				gathering.unitIDs[unitIDs[i]] = true
			end
			gathering.changed = true
		end,
		UnitsLeftArea = function(trigger, triggerID, context, unitIDs)
			local gathering = getGathering(context, triggerID)
			for i = 1, #unitIDs do
				gathering.unitIDs[unitIDs[i]] = nil
			end
			gathering.changed = true
		end,
		-- One of them lost outside the area can complete the group.
		UnitDestroyed = function(trigger, triggerID, context, unitID)
			if context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				markChanged(context, triggerID)
			end
		end,
		UnitGiven = function(trigger, triggerID, context, unitID, unitDefID, newTeam, oldTeam)
			local parameters = trigger.parameters
			if (newTeam == parameters.teamID or oldTeam == parameters.teamID)
				and context.DoesUnitHaveName(unitID, parameters.unitName) then
				markChanged(context, triggerID)
			end
		end,
	},
}
