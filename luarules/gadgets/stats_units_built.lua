local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Stats API - Units built",
		desc    = "Counts completed units per team and unit type (units_built{team_id, allyteam_id, unit_type})",
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

local unitDefName = {}
local allyTeamFor = {}

local function getAllyTeam(teamID)
	local cached = allyTeamFor[teamID]
	if cached then return cached end
	local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID)
	allyTeamFor[teamID] = allyTeamID
	return allyTeamID
end

function gadget:Initialize()
	for unitDefID, ud in pairs(UnitDefs) do
		unitDefName[unitDefID] = ud.name
	end
end

function gadget:UnitFinished(_, unitDefID, unitTeam)
	if not GG.Stats then return end
	GG.Stats.IncCounter("units_built", 1, {
		team_id     = unitTeam,
		allyteam_id = getAllyTeam(unitTeam),
		unit_type   = unitDefName[unitDefID] or "unknown",
	})
end
