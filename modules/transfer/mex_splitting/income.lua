---@class MexIncome what an ally team's mexes made, paid back evenly
local Income = {}

---@param teams table<integer, EconomyTeamResources> by team id
---@param made table<integer, table<ResourceName, number>> what each team's extractors made, by team id
---@return table<integer, table<ResourceName, number>> the same, the metal of each ally team's living members split evenly among them
function Income.Shared(teams, made)
	local members = {} ---@type table<integer, integer[]>
	for teamID, team in pairs(teams) do
		if not team.isDead and made[teamID] then
			members[team.allyTeam] = members[team.allyTeam] or {}
			table.insert(members[team.allyTeam], teamID)
		end
	end
	local income = {}
	for teamID, paid in pairs(made) do
		income[teamID] = { metal = paid.metal, energy = paid.energy }
	end
	for _, teamIDs in pairs(members) do
		local total = 0.0
		for _, teamID in ipairs(teamIDs) do
			total = total + (made[teamID].metal or 0)
		end
		for _, teamID in ipairs(teamIDs) do
			income[teamID].metal = total / #teamIDs
		end
	end
	return income
end

return Income
