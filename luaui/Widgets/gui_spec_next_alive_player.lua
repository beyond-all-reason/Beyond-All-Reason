local widget = widget ---@type Widget

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


-- Localized Spring API for performance
local spGetGameFrame = SpringShared.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = SpringUnsynced.GetSpectatingState

local processTeamDiedFrame, processTeamDiedTeamID

local function switchToTeam(teamID)
	local oldMapDrawMode = SpringUnsynced.GetMapDrawMode()
	SpringUnsynced.SelectUnitArray({})
	SpringUnsynced.SendCommands('specteam ' .. teamID)
	local newMapDrawMode = SpringUnsynced.GetMapDrawMode()
	if oldMapDrawMode == 'los' and oldMapDrawMode ~= newMapDrawMode then
		SpringUnsynced.SendCommands("togglelos")
	end
end

local function processTeamDied(teamID)
	local _, _, isDead = SpringShared.GetTeamInfo(teamID, false)
	if isDead and spGetMyTeamID() == teamID then
		local myAllyTeamID = Spring.GetMyAllyTeamID()
		-- first try alive team mates
		local teamList = SpringShared.GetTeamList(myAllyTeamID)
		for _, teamListID in ipairs(teamList) do
			local _, _, isDead = SpringShared.GetTeamInfo(teamListID, false)
			if not isDead then
				switchToTeam(teamListID)
				return
			end
		end
		teamList = SpringShared.GetTeamList()
		for _, teamListID in ipairs(teamList) do
			local _, _, isDead, _, _, allyTeamID = SpringShared.GetTeamInfo(teamListID, false)
			if not isDead and allyTeamID ~= myAllyTeamID then
				switchToTeam(teamListID)
				return
			end
		end
	end
end

function widget:TeamDied(teamID)
	local spec = spGetSpectatingState()
	if spec and spGetMyTeamID() == teamID then
		processTeamDiedFrame = spGetGameFrame() + 1
		processTeamDiedTeamID = teamID
		widgetHandler:UpdateCallIn('GameFrame')
	end
end

function widget:PlayerChanged(playerID)
	local spec = spGetSpectatingState()
	local _, _, _, teamID = SpringShared.GetPlayerInfo(playerID, false)	-- player can be spec here and team not be dead still
	if spec and teamID and spGetMyTeamID() == teamID then
		processTeamDiedFrame = spGetGameFrame() + 1
		processTeamDiedTeamID = teamID
		widgetHandler:UpdateCallIn('GameFrame')
	end
end

function widget:GameFrame(f)
	if processTeamDiedFrame and processTeamDiedFrame <= f then
		processTeamDied(processTeamDiedTeamID)
		processTeamDiedFrame = nil
		processTeamDiedTeamID = nil
	end
	widgetHandler:RemoveCallIn('GameFrame')
end
