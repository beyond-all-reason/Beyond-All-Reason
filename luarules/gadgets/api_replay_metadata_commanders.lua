local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Replay metadata API - Commanders",
		desc    = "Provides the commanders meta data after the game ends",
		author  = "uBdead",
		date    = "March 2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then
	-- SYNCED --
	return
end

-- UNSYNCED --
local commanderUnitIDs = {} -- list of commander unitIDs
local commanders = {}       -- sequential array of commander metadata

local function bufferCommanderMetadata()
	if #commanderUnitIDs > 0 then
		local frame = Spring.GetGameFrame()
		for _, unitID in ipairs(commanderUnitIDs) do
			if Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID) then
				local udid = Spring.GetUnitDefID(unitID)
				local ud = UnitDefs[udid]
				local teamID = Spring.GetUnitTeam(unitID)
				local x, y, z = Spring.GetUnitPosition(unitID)
				local health, maxHealth = Spring.GetUnitHealth(unitID)
				local xp = Spring.GetUnitExperience(unitID) or 0

				-- Find or create the commander entry in the array
				local entry = nil
				for _, cmd in ipairs(commanders) do
					if cmd.unitID == unitID then
						entry = cmd
						break
					end
				end
				if not entry then
					entry = {
						unitID = unitID,
						unitDefName = ud and ud.name or "unknown",
						teamID = teamID,
						history = {}
					}
					table.insert(commanders, entry)
				end

				-- Save only dynamic fields in history
				local healthPercent = (maxHealth and maxHealth > 0) and (health / maxHealth) or 0
				table.insert(entry.history, {
					frame = frame,
					position = { x = x, y = y, z = z },
					healthPercent = healthPercent,
					xp = xp,
				})
			end
		end
	end
end

function gadget:GameFramePost(frame)
	-- We have to wait until the commander units are created, which happens after frame 1
	if frame > 1 and #commanderUnitIDs == 0 then
		local teamList = Spring.GetTeamList()
		local gaiaTeamID = Spring.GetGaiaTeamID and Spring.GetGaiaTeamID() or 666
		for _, teamID in ipairs(teamList) do
			if teamID ~= gaiaTeamID then
				-- Include both human and AI teams (skip only Gaia)
				local units = Spring.GetTeamUnits(teamID) or {}
				for _, unitID in ipairs(units) do
					local udid = Spring.GetUnitDefID(unitID)
					local ud = UnitDefs[udid]
					if ud and ud.customParams.iscommander then
						table.insert(commanderUnitIDs, unitID)
					end
				end
			end
		end
	else
		-- every 5 seconds (150 frames) we save the commanders to metadata
		if frame % 150 == 0 then
			bufferCommanderMetadata()
		end
	end
end

function gadget:GameOver()
	Spring.Echo("[ReplayMetadata] Game over, buffering commander metadata...")
	bufferCommanderMetadata()

	if #commanderUnitIDs > 0 then
		GG.ReplayMetadata.SetReplayMetadata("commanders", commanders)
	end
end
