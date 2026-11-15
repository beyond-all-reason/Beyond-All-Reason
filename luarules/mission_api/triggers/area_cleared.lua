local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

-- A refused trigger (inactive, prerequisites, stage) asks again this much later.
local RETRY_FRAMES = 0.5 * Game.gameSpeed

---@class AreaOccupancy
---@field unitIDs table<integer, true> the tracked units inside the area
---@field changed boolean a unit came, went or changed sides
---@field occupied boolean one of theirs was inside at the last look
---@field cleared boolean the last of them is gone, and the trigger has not fired for it yet
---@field retryFrame integer? after a refused activation, the frame to ask again

local function isOccupied(unitIDs, allyTeamID)
	for unitID in pairs(unitIDs) do
		if not allyTeamID or Spring.GetUnitAllyTeam(unitID) == allyTeamID then
			return true
		end
	end
	return false
end

-- Fires when the last unit of the team or alliance inside the area dies, leaves or changes sides.
-- An area nobody of theirs was in never fires; one they come back to can fire again, if it repeats.
return {
	type = "AreaCleared",
	parameters = {
		{ name = "area", required = true, type = ParameterTypes.Area },
		{ name = "teamName", required = false, type = ParameterTypes.TeamName },
		{ name = "allianceName", required = false, type = ParameterTypes.AllianceName },
		requiresOneOf = { "teamName", "allianceName" },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, frameNumber)
			if trigger.triggered and not trigger.settings.repeating then
				return
			end
			local occupancy = context.OccupiedAreas[triggerID]
			if not occupancy then
				return
			end
			if occupancy.changed then
				local occupied = isOccupied(occupancy.unitIDs, trigger.parameters.allianceName)
				occupancy.cleared = occupancy.occupied and not occupied
				occupancy.occupied = occupied
				occupancy.changed = false
				occupancy.retryFrame = nil
			end
			if not occupancy.cleared or (occupancy.retryFrame and frameNumber < occupancy.retryFrame) then
				return
			end
			if context.ActivateTrigger(trigger) then
				occupancy.cleared = false
			else
				occupancy.retryFrame = frameNumber + RETRY_FRAMES
			end
		end,
		UnitsEnteredArea = function(trigger, triggerID, context, unitIDs)
			local occupancy = context.OccupiedAreas[triggerID]
			if not occupancy then
				occupancy = { unitIDs = {}, changed = false, occupied = false, cleared = false } ---@type AreaOccupancy
				context.OccupiedAreas[triggerID] = occupancy
			end
			for i = 1, #unitIDs do
				occupancy.unitIDs[unitIDs[i]] = true
			end
			occupancy.changed = true
		end,
		UnitsLeftArea = function(trigger, triggerID, context, unitIDs)
			local occupancy = context.OccupiedAreas[triggerID]
			if not occupancy then
				return
			end
			for i = 1, #unitIDs do
				occupancy.unitIDs[unitIDs[i]] = nil
			end
			occupancy.changed = true
		end,
		-- A unit inside that changes alliance neither enters nor leaves.
		UnitGiven = function(trigger, triggerID, context)
			local occupancy = context.OccupiedAreas[triggerID]
			if occupancy then
				occupancy.changed = true
			end
		end,
	},
}
