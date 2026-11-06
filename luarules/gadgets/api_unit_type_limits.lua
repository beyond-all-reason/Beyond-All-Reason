local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Type Limits API",
		desc = "Caps how many units of a type a team may have at once (GG.UnitTypeLimits, for missions)",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Finished units and frames count for the team that has them. At the cap the type is blocked and
-- new ones refused; spawned, given and captured units are counted, never refused.

if gadgetHandler:IsSyncedCode() then
	local REASON = "mission_limit"

	local spGetTeamUnitDefCount = Spring.GetTeamUnitDefCount
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
	local spGetFeatureResurrect = Spring.GetFeatureResurrect

	---@type table<number, table<number, number>>
	local limits = {} -- teamID -> unitDefID -> cap
	---@type table<number, table<number, number>>
	local counts = {} -- teamID -> unitDefID -> units, capped types only
	---@type table<number, table<number, boolean>>
	local blocked = {} -- teamID -> unitDefID -> published
	---@type table<UnitID, boolean>
	local overCap = {} -- frames started past the cap, removed next frame
	local clearStale = true

	local function capOf(teamID, unitDefID)
		return limits[teamID] and limits[teamID][unitDefID]
	end

	local function atCap(teamID, unitDefID)
		local cap = capOf(teamID, unitDefID)
		return cap ~= nil and counts[teamID][unitDefID] >= cap
	end

	-- Published only when it changes.
	local function refresh(teamID, unitDefID)
		local over = atCap(teamID, unitDefID)
		blocked[teamID] = blocked[teamID] or {}
		if over == (blocked[teamID][unitDefID] == true) then
			return
		end
		blocked[teamID][unitDefID] = over or nil
		if over then
			GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, REASON)
		else
			GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, REASON)
		end
	end

	local function add(teamID, unitDefID, n)
		local teamCounts = counts[teamID]
		if teamCounts and teamCounts[unitDefID] then
			teamCounts[unitDefID] = teamCounts[unitDefID] + n
			refresh(teamID, unitDefID)
		end
	end

	-- A builder placing the blueprint of a frame already there assists it: no new unit.
	local function assists(unitDefID, teamID, x, z)
		if not x then
			return false
		end
		local def = UnitDefs[unitDefID]
		local radius = def and math.max(def.xsize, def.zsize) * 4 or 16
		for _, unitID in ipairs(spGetUnitsInCylinder(x, z, radius)) do
			if
				spGetUnitDefID(unitID) == unitDefID
				and spGetUnitTeam(unitID) == teamID
				and spGetUnitIsBeingBuilt(unitID)
			then
				return true
			end
		end
		return false
	end

	GG.UnitTypeLimits = {
		--- At most `cap` units of `unitDefID` for `teamID`; nil takes the cap away.
		Set = function(teamID, unitDefID, cap)
			limits[teamID] = limits[teamID] or {}
			counts[teamID] = counts[teamID] or {}
			limits[teamID][unitDefID] = cap
			counts[teamID][unitDefID] = cap and spGetTeamUnitDefCount(teamID, unitDefID) or nil
			refresh(teamID, unitDefID)
		end,
	}

	function gadget:Shutdown()
		GG.UnitTypeLimits = nil
	end

	function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
		add(teamID, unitDefID, 1)
		-- Two factories can start the last one in the same frame.
		local cap = capOf(teamID, unitDefID)
		if builderID and cap and counts[teamID][unitDefID] > cap then
			overCap[unitID] = true
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID)
		overCap[unitID] = nil
		add(teamID, unitDefID, -1)
	end

	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		add(oldTeam, unitDefID, -1)
		add(newTeam, unitDefID, 1)
	end

	function gadget:GameFrame()
		-- A reload forgets the caps, not the blocks they published.
		if clearStale then
			clearStale = false
			for _, teamID in ipairs(Spring.GetTeamList() or {}) do
				for unitDefID in pairs(UnitDefs) do
					if not atCap(teamID, unitDefID) then
						GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, REASON)
					end
				end
			end
		end
		for unitID in pairs(overCap) do
			overCap[unitID] = nil
			if spGetUnitIsBeingBuilt(unitID) then
				Spring.DestroyUnit(unitID, false, true)
			end
		end
	end

	function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
		-- The second value drops a refused order.
		return not atCap(builderTeam, unitDefID) or assists(unitDefID, builderTeam, x, z), true
	end

	function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
		if part <= 0 then
			return true
		end
		local name = spGetFeatureResurrect(featureID)
		local def = name and name ~= "" and UnitDefNames[name]
		return not (def and atCap(builderTeam, def.id))
	end
end
