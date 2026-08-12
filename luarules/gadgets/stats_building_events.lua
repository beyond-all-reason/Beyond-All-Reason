local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Stats API - Building events",
		desc    = "Emits building_constructed{team_id, allyteam_id, unit_type, pos_x, pos_y, pos_z} when a building is finished",
		author  = "bruno-dasilva",
		date    = "May 2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local buildingName = {}
local allyTeamFor  = {}

local function getAllyTeam(teamID)
	local cached = allyTeamFor[teamID]
	if cached then return cached end
	local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID)
	allyTeamFor[teamID] = allyTeamID
	return allyTeamID
end

function gadget:Initialize()
	for unitDefID, ud in pairs(UnitDefs) do
		if ud.isBuilding then
			buildingName[unitDefID] = ud.name
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local name = buildingName[unitDefID]
	if not name then return end
	if not GG.Stats then return end
	GG.Stats.EmitEvent("building_constructed", {
		team_id     = unitTeam,
		allyteam_id = getAllyTeam(unitTeam),
		unit_type   = name,
	})
end
