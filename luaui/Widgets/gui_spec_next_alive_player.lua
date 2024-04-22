function widget:GetInfo()
	return {
		name      = 'Spectate Next Alive Player',
		desc      = 'Auto spectate another alive player when currently selected player died',
		author    = 'Floris',
		date      = 'February 2024',
		license	  = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

local spec, fullview = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local processTeamDiedFrame, processTeamDiedTeamID, processTeamDiedTeamID

local function switchToTeam(teamID)
	local oldMapDrawMode = Spring.GetMapDrawMode()
	Spring.SelectUnitArray({})
	Spring.SendCommands('specteam ' .. teamID)
	local newMapDrawMode = Spring.GetMapDrawMode()
	if oldMapDrawMode == 'los' and oldMapDrawMode ~= newMapDrawMode then
		Spring.SendCommands("togglelos")
	end
end

local function processTeamDied(teamID)
	if teamID then
		local _, _, isDead = Spring.GetTeamInfo(teamID, false)
		if isDead and myTeamID == teamID then
			local myAllyTeamID = Spring.GetMyAllyTeamID()
			-- first try alive team mates
			local teamList = Spring.GetTeamList(myAllyTeamID)
			for _, teamListID in ipairs(teamList) do
				local _, _, isDead = Spring.GetTeamInfo(teamListID, false)
				if not isDead then
					switchToTeam(teamListID)
					return
				end
			end
			teamList = Spring.GetTeamList()
			for _, teamListID in ipairs(teamList) do
				local _, _, isDead, _, _, allyTeamID = Spring.GetTeamInfo(teamListID, false)
				if not isDead then
					switchToTeam(teamListID)
					return
				end
			end
		end
	end
end

function widget:TeamDied(teamID)
	spec, fullview = Spring.GetSpectatingState()
	if spec and myTeamID == teamID then
		processTeamDiedFrame = Spring.GetGameFrame() + 1
		processTeamDiedTeamID = teamID
	end
end

function widget:PlayerChanged(playerID)
	spec, fullview = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)	-- player can be spec here and team not be dead still
	if spec and teamID and myTeamID == teamID then
		processTeamDiedFrame = Spring.GetGameFrame() + 1
		processTeamDiedTeamID = teamID
	end
end

function widget:GameFrame(f)
	if processTeamDiedFrame and processTeamDiedFrame <= f then
		processTeamDied(processTeamDiedTeamID)
		processTeamDiedFrame = nil
		processTeamDiedTeamID = nil
	end
end
