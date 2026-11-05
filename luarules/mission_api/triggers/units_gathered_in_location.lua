local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local matchingUnits = GG['MissionAPI'].Modules.UnitQuery.MatchingUnits

-- A trigger refused while they are all inside (inactive, prerequisites, stage) asks again half a second later.
local RETRY_FRAMES = 15

---@class Gathering
---@field unitIDs table<integer, true> the team's units inside the area
---@field changed boolean something happened that can complete the group
---@field fired boolean fired for this gathering, until one of them walks out
---@field retryFrame integer? after a refused activation, the frame to ask again

---@return Gathering
local function getGathering(context, triggerID)
	local gathering = context.GatheredUnitsInAreas[triggerID]
	if not gathering then
		gathering = { unitIDs = {}, changed = false, fired = false } ---@type Gathering
		context.GatheredUnitsInAreas[triggerID] = gathering
	end
	return gathering
end

-- A dead, captured or given away unit has left the group, and one still being built cannot walk in.
---@return boolean
local function isGathered(parameters, unitIDsInside)
	local anyWaitedFor = false
	for _, unitID in ipairs(matchingUnits(parameters.unitName, nil, parameters.teamName)) do
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
	local gathering = context.GatheredUnitsInAreas[triggerID]
	if gathering then
		gathering.changed = true
	end
end

-- Fires once when every unit named unitName on teamName is inside the area, and again only after
-- one has walked out and they are all back, if it repeats.
return {
	type = 'UnitsGatheredInLocation',
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }
		{ name = 'area',     required = true, type = ParameterTypes.Area },
		{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
		{ name = 'teamName', required = true, type = ParameterTypes.TeamName },
	},
	callins = {
		-- Looking at the group costs engine calls per unit, so it is done last: only after something
		-- changed, before this gathering has fired, and not before a refused trigger's retry frame.
		GameFrame = function(trigger, triggerID, context, frameNumber)
			if trigger.triggered and not trigger.settings.repeating then
				return
			end
			local gathering = context.GatheredUnitsInAreas[triggerID]
			if not gathering or not gathering.changed or gathering.fired then
				return
			end
			if gathering.retryFrame and frameNumber < gathering.retryFrame then
				return
			end

			if not isGathered(trigger.parameters, gathering.unitIDs) then
				gathering.changed = false
				gathering.retryFrame = nil
			elseif context.ActivateTrigger(trigger) then
				gathering.fired = true
				gathering.changed = false
				gathering.retryFrame = nil
			else
				gathering.retryFrame = frameNumber + RETRY_FRAMES
			end
		end,
		UnitsEnteredArea = function(trigger, triggerID, context, unitIDs)
			local gathering = getGathering(context, triggerID)
			for i = 1, #unitIDs do
				gathering.unitIDs[unitIDs[i]] = true
			end
			gathering.changed = true
		end,
		-- One of them walking out parts the group. One that died or changed team only leaves it.
		UnitsLeftArea = function(trigger, triggerID, context, unitIDs)
			local parameters = trigger.parameters
			local gathering = getGathering(context, triggerID)
			for i = 1, #unitIDs do
				local unitID = unitIDs[i]
				gathering.unitIDs[unitID] = nil
				if gathering.fired and context.DoesUnitHaveName(unitID, parameters.unitName)
					and Spring.GetUnitTeam(unitID) == parameters.teamName then
					gathering.fired = false
				end
			end
			gathering.changed = true
		end,
		-- One built inside the area was in it all along, and counts once it is finished.
		UnitFinished = function(trigger, triggerID, context, unitID)
			local gathering = context.GatheredUnitsInAreas[triggerID]
			if gathering and gathering.unitIDs[unitID] then
				gathering.changed = true
			end
		end,
		-- One of them lost outside the area can complete the group.
		UnitDestroyed = function(trigger, triggerID, context, unitID)
			if context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				markChanged(context, triggerID)
			end
		end,
		UnitGiven = function(trigger, triggerID, context, unitID, unitDefID, newTeam, oldTeam)
			local parameters = trigger.parameters
			if (newTeam == parameters.teamName or oldTeam == parameters.teamName)
				and context.DoesUnitHaveName(unitID, parameters.unitName) then
				markChanged(context, triggerID)
			end
		end,
	},
}
