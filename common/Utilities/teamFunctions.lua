local teamCount
local is1v1, isTeams, isBigTeams, isSmallTeams, isChickens, isCoop, isFFA, isSandbox, isPlanetWars = false, false, false, false, false, false, false, false, false
do
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
	local allyTeamList = Spring.GetAllyTeamList()
	local actualAllyTeamList = {}
	local entirelyHumanAllyTeams = {}
	for i = 1, #allyTeamList do
		local teamList = Spring.GetTeamList(allyTeamList[i]) or {}
		local allyteamEntirelyHuman = true
		if #teamList > 0 and allyTeamList[i] ~= gaiaAllyTeamID then
			local isTeamValid = true
			for j = 1, #teamList do
				if select (4, Spring.GetTeamInfo(teamList[j], false)) then
					allyteamEntirelyHuman = false
				end
				local luaAI = Spring.GetTeamLuaAI(teamList[j])
				if luaAI and luaAI:find("Chicken") then
					isChickens = true
					isTeamValid = false
				end
			end
			if isTeamValid then
				actualAllyTeamList[#actualAllyTeamList+1] = allyTeamList[i]
			end
			if allyteamEntirelyHuman then
				entirelyHumanAllyTeams[#entirelyHumanAllyTeams+1] = allyTeamList[i]
			end
		end
	end
	teamCount = #actualAllyTeamList

	if teamCount > 2 then
		isFFA = true
		isChickens = false
	elseif teamCount < 2 then
		isSandbox = not isChickens
	else
		isChickens = false
		local cnt1 = #Spring.GetTeamList(actualAllyTeamList[1])
		local cnt2 = #Spring.GetTeamList(actualAllyTeamList[2])
		if cnt1 == 1 and cnt2 == 1 then
			is1v1 = true
		else
			isTeams = true
			if cnt1 <= 4 and cnt2 <= 4 then
				isSmallTeams = true
			else
				isBigTeams = true
			end
		end
	end

	if #entirelyHumanAllyTeams == 1 and #Spring.GetTeamList(entirelyHumanAllyTeams[1]) > 1 then
		isCoop = true
	end

	if Spring.GetModOptions().planet then
		isPlanetWars = true
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
		IsCoop       = function () return isCoop       end,
		IsFFA        = function () return isFFA        end,
		IsSandbox    = function () return isSandbox    end,
		IsPlanetWars = function () return isPlanetWars end,
	},
}