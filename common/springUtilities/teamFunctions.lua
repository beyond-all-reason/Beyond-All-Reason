local smallTeamThreshold = 4
local initialized = false
local settings = { }

local function getSettings()
	if initialized then
		return settings
	end

	local allyTeamCount, playerCount = 0, 0
	local isSinglePlayer, is1v1, isTeams, isBigTeams, isSmallTeams, isRaptors, isScavengers, isPvE, isCoop, isFFA, isSandbox = false, false, false, false, false, false, false, false, false, false, false

	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
	local springAllyTeamList = Spring.GetAllyTeamList()
	local allyTeamList = {}
	local allyTeamSizes = {}
	local entirelyHumanAllyTeams = {}

	for _, allyTeam in ipairs(springAllyTeamList) do
		local teamList = Spring.GetTeamList(allyTeam) or {}
		local allyteamEntirelyHuman = true

		if #teamList > 0 and allyTeam ~= gaiaAllyTeamID then
			local isAllyTeamValid = true

			for _, team in ipairs(teamList) do
				if select (4, Spring.GetTeamInfo(team, false)) then
					allyteamEntirelyHuman = false
				else
					local teamPlayers = Spring.GetPlayerList(team)
					for _, playerID in ipairs(teamPlayers) do
						playerCount = playerCount + 1
					end
				end

				local luaAI = Spring.GetTeamLuaAI(team)

				if luaAI then
					if luaAI:find("Raptors") then
						isRaptors = true
						isAllyTeamValid = false
					elseif luaAI:find("Scavengers") then
						isScavengers = true
						isAllyTeamValid = false
					end
				end
			end

			if isAllyTeamValid then
				allyTeamList[#allyTeamList+1] = allyTeam
				allyTeamSizes[#allyTeamSizes+1] = #teamList
			end

			if allyteamEntirelyHuman then
				entirelyHumanAllyTeams[#entirelyHumanAllyTeams+1] = allyTeam
			end
		end
	end

	allyTeamCount = #allyTeamList

	isSmallTeams = true
	for _, teamSize in ipairs(allyTeamSizes) do
		if teamSize > 1 then
			isTeams = true
		end

		isSmallTeams = isSmallTeams and teamSize <= smallTeamThreshold
	end

	isSinglePlayer = playerCount == 1
	isSmallTeams = isTeams and isSmallTeams
	isBigTeams = isTeams and not isSmallTeams
	isPvE = isRaptors or isScavengers

	if allyTeamCount > 2 then
		isFFA = true
	elseif allyTeamCount < 2 and not isPvE then
		isSandbox = true
	elseif allyTeamCount == 2 and not isTeams then
		is1v1 = true
	end

	if #entirelyHumanAllyTeams == 1 and #Spring.GetTeamList(entirelyHumanAllyTeams[1]) > 1 then
		isCoop = true
	end

	initialized = true

	settings = {
		allyTeamCount = allyTeamCount,
		allyTeamList = allyTeamList,
		playerCount = playerCount,
		isSinglePlayer = isSinglePlayer,
		is1v1 = is1v1,
		isTeams = isTeams,
		isBigTeams = isBigTeams,
		isSmallTeams = isSmallTeams,
		isRaptors = isRaptors,
		isScavengers = isScavengers,
		isPvE = isPvE,
		isCoop = isCoop,
		isFFA = isFFA,
		isSandbox = isSandbox,
	}

	return settings
end

return {
	---Get number of ally teams (humans and AIs, but not Raptors and Scavengers).
	GetAllyTeamCount = function() return getSettings().allyTeamCount end,
	---Get ally team list (humans and AIs, but not Raptors and Scavengers).
	---@return integer[] allyTeamList table[i] = allyTeamID
	GetAllyTeamList  = function () return getSettings().allyTeamList end,
	GetPlayerCount   = function () return getSettings().playerCount end,
	Gametype = {
		IsSinglePlayer = function () return getSettings().isSinglePlayer end,
		Is1v1          = function () return getSettings().is1v1          end,
		IsTeams        = function () return getSettings().isTeams        end,
		IsBigTeams     = function () return getSettings().isBigTeams     end,
		IsSmallTeams   = function () return getSettings().isSmallTeams   end,
		IsRaptors      = function () return getSettings().isRaptors      end,
		IsScavengers   = function () return getSettings().isScavengers   end,
		IsPvE          = function () return getSettings().isPvE          end,
		IsCoop         = function () return getSettings().isCoop         end,
		IsFFA          = function () return getSettings().isFFA          end,
		IsSandbox      = function () return getSettings().isSandbox      end,
	},
}
