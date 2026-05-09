local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Stats API - Engine metrics",
		desc    = "Mirrors per-team engine stats (metal/energy/damage/units) into counters by polling Spring.GetTeamStatsHistory once per reporting period",
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

local TRACKED_FIELDS = {
	metalProduced  = "metal_produced",
	metalUsed      = "metal_used",
	energyProduced = "energy_produced",
	energyUsed     = "energy_used",
	damageDealt    = "damage_dealt",
	damageReceived = "damage_received",
	unitsProduced  = "units_produced",
	unitsKilled    = "units_killed",
	unitsDied      = "units_died",
}

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
		local cur_max = Spring.GetTeamStatsHistory(teamID)
		if cur_max and cur_max > 0 then
			local statsArr = Spring.GetTeamStatsHistory(teamID, cur_max, cur_max)
			local stats = statsArr and statsArr[1]
			if stats then
				local labels = {
					team_id     = teamID,
					allyteam_id = getAllyTeam(teamID),
				}
				for engineField, counterName in pairs(TRACKED_FIELDS) do
					GG.Stats.OverrideCounter(counterName, stats[engineField] or 0, labels)
				end
			end
		end
	end
end
