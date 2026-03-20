local smallTeamThreshold = 4
local initialized = false
local settings = { }

local holidaysList = VFS.Include("common/holidays.lua")

local function getSettings()
	if initialized then
		return settings
	end

	local allyTeamCount, playerCount = 0, 0
	local isSinglePlayer, is1v1, isTeams, isBigTeams, isSmallTeams, isRaptors, isScavengers, isPvE, isCoop, isFFA, isSandbox = false, false, false, false, false, false, false, false, false, false, false
	local scavTeamID, scavAllyTeamID, raptorTeamID, raptorAllyTeamID
	local isHoliday = {}

	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
	local springAllyTeamList = Spring.GetAllyTeamList()
	local allyTeamList = {}
	local allyTeamSizes = {}
	local entirelyHumanAllyTeams = {}

	for _, allyTeamID in ipairs(springAllyTeamList) do
		local teamList = Spring.GetTeamList(allyTeamID) or {}
		local allyteamEntirelyHuman = true

		if #teamList > 0 and allyTeamID ~= gaiaAllyTeamID then
			local isAllyTeamValid = true

			for _, teamID in ipairs(teamList) do
				if select (4, Spring.GetTeamInfo(teamID, false)) then
					allyteamEntirelyHuman = false
				else
					local teamPlayers = Spring.GetPlayerList(teamID)
					for _, playerID in ipairs(teamPlayers) do
						playerCount = playerCount + 1
					end
				end

				local luaAI = Spring.GetTeamLuaAI(teamID)

				if luaAI then
					if luaAI:find("Raptors") then
						isRaptors = true
						isAllyTeamValid = false
						raptorTeamID = teamID
						raptorAllyTeamID = allyTeamID
					elseif luaAI:find("Scavengers") then
						isScavengers = true
						isAllyTeamValid = false
						scavTeamID = teamID
						scavAllyTeamID = allyTeamID
					end
				end
			end

			if isAllyTeamValid then
				allyTeamList[#allyTeamList+1] = allyTeamID
				allyTeamSizes[#allyTeamSizes+1] = #teamList
			end

			if allyteamEntirelyHuman then
				entirelyHumanAllyTeams[#entirelyHumanAllyTeams+1] = allyTeamID
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

	if holidaysList and Spring.GetModOptions and Spring.GetModOptions().date_day then
		local currentDay = Spring.GetModOptions().date_day
		local currentMonth = Spring.GetModOptions().date_month
		local currentYear = Spring.GetModOptions().date_year

		-- FIXME: This doesn't support events that start and end in different years.
		for holiday, dates in pairs(holidaysList) do
			local afterStart = false
			local beforeEnd = false
			if (dates.firstDay.month == currentMonth and dates.firstDay.day <= currentDay) or (dates.firstDay.month < currentMonth) then
				afterStart = true
			end
			if (dates.lastDay.month == currentMonth and dates.lastDay.day >= currentDay) or (dates.lastDay.month > currentMonth) then
				beforeEnd = true
			end

			if afterStart and beforeEnd then
				isHoliday[holiday] = true
			else
				isHoliday[holiday] = false
			end
		end
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
		scavTeamID = scavTeamID,
		scavAllyTeamID = scavAllyTeamID,
		raptorTeamID = raptorTeamID,
		raptorAllyTeamID = raptorAllyTeamID,
		isHoliday = isHoliday,
	}

	return settings
end

return {
	---Get number of ally teams (humans and AIs, but not Raptors and Scavengers).
	GetAllyTeamCount = function() return getSettings().allyTeamCount end,
	---Get ally team list (humans and AIs, but not Raptors and Scavengers).
	---@return integer[] allyTeamList table[i] = allyTeamID
	GetAllyTeamList  = function () return getSettings().allyTeamList end,
	---@return integer? playerCount Get number of players in a game, nil If it's an AI only game.
	GetPlayerCount   = function () return getSettings().playerCount end,
	Gametype = {
		---@return boolean
		IsSinglePlayer = function () return getSettings().isSinglePlayer end,
		---@return boolean
		Is1v1          = function () return getSettings().is1v1          end,
		---@return boolean
		IsTeams        = function () return getSettings().isTeams        end,
		---@return boolean
		IsBigTeams     = function () return getSettings().isBigTeams     end,
		---@return boolean
		IsSmallTeams   = function () return getSettings().isSmallTeams   end,
		---@return boolean
		IsRaptors      = function () return getSettings().isRaptors      end,
		---@return boolean
		IsScavengers   = function () return getSettings().isScavengers   end,
		---@return boolean
		IsPvE          = function () return getSettings().isPvE          end,
		---@return boolean
		IsCoop         = function () return getSettings().isCoop         end,
		---@return boolean
		IsFFA          = function () return getSettings().isFFA          end,
		---@return boolean
		IsSandbox      = function () return getSettings().isSandbox      end,
		---@return table? isHoliday Currently running holiday events. 
		---See common/holidays.lua for more information.
		GetCurrentHolidays = function () return getSettings().isHoliday end,
	},
	---@return integer? scavTeamID Team ID for the scavenger team.
	GetScavTeamID = function () return getSettings().scavTeamID end,
	---@return integer? scavAllyTeamID Team ID for the scavenger ally team.
	GetScavAllyTeamID = function () return getSettings().scavAllyTeamID end,
	---@return integer? raptorTeamID Team ID for the raptor team.
	GetRaptorTeamID = function () return getSettings().raptorTeamID end,
	---@return integer? raptorAllyTeamID Team ID for the raptor ally team.
	GetRaptorAllyTeamID = function () return getSettings().raptorAllyTeamID end,

}
