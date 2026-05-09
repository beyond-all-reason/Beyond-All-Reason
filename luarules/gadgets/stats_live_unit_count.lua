local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Stats API - Live unit count",
		desc    = "Records live_unit_count{team_id, allyteam_id} by polling Spring.GetTeamUnitCount once per reporting period",
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

local POLL_FRAMES = 450

local teams
local allyTeamFor = {}

local function getAllyTeam(teamID)
	local cached = allyTeamFor[teamID]
	if cached then return cached end
	local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID)
	allyTeamFor[teamID] = allyTeamID
	return allyTeamID
end

function gadget:GameFrame(frame)
	if frame % POLL_FRAMES ~= 0 then return end
	if not GG.Stats then return end
	teams = teams or Spring.GetTeamList() or {}
	for i = 1, #teams do
		local teamID = teams[i]
		GG.Stats.SetGauge("live_unit_count", Spring.GetTeamUnitCount(teamID) or 0, {
			team_id     = teamID,
			allyteam_id = getAllyTeam(teamID),
		})
	end
end
