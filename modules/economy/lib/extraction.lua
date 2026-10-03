local Construction = require("modules/construction/api")

---@class EconomyExtraction what the extractors make: the engine's per-unit rates, summed per team over a tick
local Extraction = {}

---@param springRepo Spring
---@param teamID integer
---@param defIDs integer[]
---@param which "metal"|"energy"
---@return number per second
local function rate(springRepo, teamID, defIDs, which)
	local total = 0.0
	for _, unitID in ipairs(springRepo.GetTeamUnitsByDefs(teamID, defIDs) or {}) do
		local metalMake, _, energyMake = springRepo.GetUnitResources(unitID)
		total = total + ((which == "metal" and metalMake or energyMake) or 0)
	end
	return total
end

---@param springRepo Spring
---@param teamIDs integer[]
---@param seconds number
---@return table<integer, table<ResourceName, number>> what each team's mexes and geos made over the tick
function Extraction.Made(springRepo, teamIDs, seconds)
	local mexes, geos = Construction.Mexes(), Construction.Geos()
	local made = {}
	for _, teamID in ipairs(teamIDs) do
		made[teamID] = {
			metal = rate(springRepo, teamID, mexes, "metal") * seconds,
			energy = rate(springRepo, teamID, geos, "energy") * seconds,
		}
	end
	return made
end

return Extraction
