local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Type Limits API",
		desc = "Limits how many units of a type a team may have at once (GG.UnitTypeLimits, for missions)",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1, -- after the Mission API
		enabled = true,
	}
end

-- Finished units and frames count for the team that has them. At the limit the type is blocked and
-- new or shared ones refused; spawned and captured units are counted, never refused.

if gadgetHandler:IsSyncedCode() then
	local REASON_KEY = "mission_limit"

	local unitBlocking = require("common/unitBlocking")

	local spGetTeamUnitDefCount = Spring.GetTeamUnitDefCount
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitTeam = Spring.GetUnitTeam
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
	local spGetFeatureResurrect = Spring.GetFeatureResurrect

	local limits = {} ---@type table<TeamID, table<UnitDefID, integer>>
	local counts = {} ---@type table<TeamID, table<UnitDefID, integer>> limited types only
	local blocked = {} ---@type table<TeamID, table<UnitDefID, boolean>> published
	local overLimit = {} ---@type table<UnitID, boolean> frames started past the limit, removed next frame
	local clearStale = false

	local function getUnitTypeLimit(teamID, unitDefID)
		return limits[teamID] and limits[teamID][unitDefID]
	end

	local function atLimit(teamID, unitDefID)
		local limit = getUnitTypeLimit(teamID, unitDefID)
		return limit ~= nil and counts[teamID][unitDefID] >= limit
	end

	-- Published only when it changes.
	local function refresh(teamID, unitDefID)
		local over = atLimit(teamID, unitDefID)
		blocked[teamID] = blocked[teamID] or {}
		if over == (blocked[teamID][unitDefID] == true) then
			return
		end
		blocked[teamID][unitDefID] = over or nil
		if over then
			GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, REASON_KEY)
		else
			GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, REASON_KEY)
		end
	end

	local function countUnits(teamID, unitDefID, delta)
		local teamCounts = counts[teamID]
		if teamCounts and teamCounts[unitDefID] then
			teamCounts[unitDefID] = teamCounts[unitDefID] + delta
			refresh(teamID, unitDefID)
		end
	end

	-- As the engine does: a blueprint on the footprint of an allied frame of its type assists it, no new unit.
	local function assistsPlacedFrame(unitDefID, teamID, x, z, facing)
		if not x then
			return false
		end
		local def = UnitDefs[unitDefID]
		local width, depth = def.xsize * 8, def.zsize * 8
		if facing == 1 or facing == 3 then
			width, depth = depth, width
		end
		for _, unitID in ipairs(spGetUnitsInCylinder(x, z, math.diag(width, depth))) do
			local ux, _, uz = spGetUnitPosition(unitID)
			if
				spGetUnitDefID(unitID) == unitDefID
				and spAreTeamsAllied(spGetUnitTeam(unitID), teamID)
				and spGetUnitIsBeingBuilt(unitID)
				and math.abs(ux - x) < width
				and math.abs(uz - z) < depth
			then
				return true
			end
		end
		return false
	end

	function gadget:Initialize()
		if not Spring.GetGameRulesParam("inMission") then
			gadgetHandler:RemoveGadget()
			return
		end
		-- A reload forgets the limits, not the blocks they published; a fresh start has none.
		clearStale = Spring.GetGameFrame() > 0
		GG.UnitTypeLimits = {
			--- At most `limit` units of `unitDefID` for `teamID`; nil takes the limit away.
			Set = function(teamID, unitDefID, limit)
				limits[teamID] = limits[teamID] or {}
				counts[teamID] = counts[teamID] or {}
				limits[teamID][unitDefID] = limit
				counts[teamID][unitDefID] = limit and spGetTeamUnitDefCount(teamID, unitDefID) or nil
				refresh(teamID, unitDefID)
			end,
			--- The limit and the count of `unitDefID` for `teamID`; nil without a limit.
			Get = function(teamID, unitDefID)
				local limit = getUnitTypeLimit(teamID, unitDefID)
				return limit, limit and counts[teamID][unitDefID] or nil
			end,
		}
	end

	function gadget:Shutdown()
		GG.UnitTypeLimits = nil
	end

	function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
		countUnits(teamID, unitDefID, 1)
		-- A factory checks the limit when it takes the order and creates the unit when its yard opens,
		-- so two can pass with one slot left.
		local limit = getUnitTypeLimit(teamID, unitDefID)
		if builderID and limit and counts[teamID][unitDefID] > limit then
			overLimit[unitID] = true
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID)
		overLimit[unitID] = nil
		countUnits(teamID, unitDefID, -1)
	end

	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		countUnits(oldTeam, unitDefID, -1)
		countUnits(newTeam, unitDefID, 1)
	end

	function gadget:GameFrame()
		if clearStale then
			clearStale = false
			for _, teamID in ipairs(Spring.GetTeamList() or {}) do
				for unitDefID, reasons in pairs(unitBlocking.getBlockedUnitDefs(teamID)) do
					if reasons[REASON_KEY] and not atLimit(teamID, unitDefID) then
						GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, REASON_KEY)
					end
				end
			end
		end
		for unitID in pairs(overLimit) do
			overLimit[unitID] = nil
			if spGetUnitIsBeingBuilt(unitID) then
				Spring.DestroyUnit(unitID, false, true)
			end
		end
	end

	function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
		-- The second value drops a refused order.
		return not atLimit(builderTeam, unitDefID) or assistsPlacedFrame(unitDefID, builderTeam, x, z, facing), true
	end

	-- Captures go through so capture objectives still work.
	function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
		return capture or not atLimit(newTeam, unitDefID)
	end

	function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
		if part <= 0 then
			return true
		end
		local name = spGetFeatureResurrect(featureID)
		local def = name and name ~= "" and UnitDefNames[name]
		return not (def and atLimit(builderTeam, def.id))
	end
end
