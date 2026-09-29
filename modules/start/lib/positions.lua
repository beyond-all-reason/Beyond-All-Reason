---@class StartPositions the start positions the engine holds, one per team that has placed
local Positions = {}

---@class StartPosition
---@field allyTeamID integer
---@field teamID integer
---@field x number
---@field z number

---@param springRepo Spring
---@return StartPosition[] every team's start position known to the engine, in team order; gaia and the unplaced left out
function Positions.Read(springRepo)
	local out = {} ---@type StartPosition[]
	local gaia = springRepo.GetGaiaTeamID and springRepo.GetGaiaTeamID() or nil
	for _, teamID in ipairs(springRepo.GetTeamList() or {}) do
		if teamID ~= gaia then
			local x, _, z = springRepo.GetTeamStartPosition(teamID)
			if x and z and (x > 0 or z > 0) then
				local allyTeamID = springRepo.GetTeamAllyTeamID(teamID) or 0
				out[#out + 1] = { allyTeamID = allyTeamID, teamID = teamID, x = x, z = z }
			end
		end
	end
	return out
end

return Positions
