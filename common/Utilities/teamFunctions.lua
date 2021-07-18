local teamSizeThreshold = 4
local teamCount
local is1v1, isTeams, isBigTeams, isSmallTeams, isChickens, isScavengers, isPvE, isCoop, isFFA, isSandbox = false, false, false, false, false, false, false, false, false, false

do
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
	local allyTeamList = Spring.GetAllyTeamList()
	local actualAllyTeamList = {}
	local actualAllyTeamSizes = {}
	local entirelyHumanAllyTeams = {}

	for _, allyTeam in ipairs(allyTeamList) do
		local teamList = Spring.GetTeamList(allyTeam) or {}
		local allyteamEntirelyHuman = true

		if #teamList > 0 and allyTeam ~= gaiaAllyTeamID then
			local isAllyTeamValid = true

			for _, team in ipairs(teamList) do
				if select (4, Spring.GetTeamInfo(team, false)) then
					allyteamEntirelyHuman = false
				end

				local luaAI = Spring.GetTeamLuaAI(team)

				if luaAI then
					if luaAI:find("Chicken") then
						isChickens = true
						isAllyTeamValid = false
					elseif luaAI:find("Scavengers") then
						isScavengers = true
						isAllyTeamValid = false
					end
				end
			end

			if isAllyTeamValid then
				actualAllyTeamList[#actualAllyTeamList+1] = allyTeam
				actualAllyTeamSizes[#actualAllyTeamSizes+1] = #teamList
			end

			if allyteamEntirelyHuman then
				entirelyHumanAllyTeams[#entirelyHumanAllyTeams+1] = allyTeam
			end
		end
	end

	teamCount = #actualAllyTeamList

	isSmallTeams = true
	for _, teamSize in ipairs(actualAllyTeamSizes) do
		if teamSize > 1 then
			isTeams = true
		end

		isSmallTeams = isSmallTeams and teamSize <= teamSizeThreshold
	end

	isSmallTeams = isTeams and isSmallTeams
	isBigTeams = isTeams and not isSmallTeams
	isPvE = isChickens or isScavengers

	if teamCount > 2 then
		isFFA = true
	elseif teamCount < 2 and not isPvE then
		isSandbox = true
	elseif teamCount == 2 and not isTeams then
		is1v1 = true
	end

	if #entirelyHumanAllyTeams == 1 and #Spring.GetTeamList(entirelyHumanAllyTeams[1]) > 1 then
		isCoop = true
	end
end

local function getTeamCount()
	return teamCount
end

return {
	GetTeamCount = getTeamCount,
	Gametype = {
		Is1v1        = function () return is1v1        end,
		IsTeams      = function () return isTeams      end,
		IsBigTeams   = function () return isBigTeams   end,
		IsSmallTeams = function () return isSmallTeams end,
		IsChickens   = function () return isChickens   end,
		IsScavengers = function () return isScavengers end,
		IsPvE        = function () return isPvE        end,
		IsCoop       = function () return isCoop       end,
		IsFFA        = function () return isFFA        end,
		IsSandbox    = function () return isSandbox    end,
	},
}