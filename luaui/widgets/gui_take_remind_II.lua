
function widget:GetInfo()
	return {
		name      = "Take Reminder II",
		desc      = "Improved Take Reminder",
		author    = "Niobium",
		date      = "April 2011",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

local checkEvery = 1.0
local buttonWidth = 360
local buttonHeight = 36

local spGetSpectatingState = Spring.GetSpectatingState
local spGetPlayerList = Spring.GetPlayerList
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamList = Spring.GetTeamList
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamUnitCount = Spring.GetTeamUnitCount
local spGetTeamRulesParam = Spring.GetTeamRulesParam

--local takeableTeams = {} -- takeableTeams[1..n] = tID
local takeableCount = 0

local function GetButtonPosition()
    local vsx, vsy = gl.GetViewSizes()
    return 0.65 * vsx, 0.7 * vsy
end

local tt = 0
function widget:Update(dt)
    
	tt = tt + dt
    if tt < checkEvery then return end
    tt = 0
    
    -- Silent disable if spectator
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end
	local myTeamID = spGetMyTeamID()
	-- Search allied teams for units to take
    --takeableTeams = {}
    takeableCount = 0
	local teamList = spGetTeamList(spGetMyAllyTeamID())
	for i = 1, #teamList do
        local tID = teamList[i]
		if tID ~= myTeamID and spGetTeamRulesParam(tID, "numActivePlayers" ) == 0 then
			--takeableTeams[#takeableTeams + 1] = tID
	        takeableCount = takeableCount + spGetTeamUnitCount(tID)
		end
	end
end

function widget:DrawScreen()
    
    if takeableCount == 0 then return end
    
    local posx, posy = GetButtonPosition()
    gl.Color(1, math.abs(os.clock() % 2 - 1), 0, 0.5)
    gl.Rect(posx, posy, posx + buttonWidth, posy + buttonHeight)
    gl.Color(0, 0, 0, 1)
    gl.Shape(GL.LINE_LOOP, {{ v = { posx              , posy                }}, 
                            { v = { posx              , posy + buttonHeight }}, 
                            { v = { posx + buttonWidth, posy + buttonHeight }}, 
                            { v = { posx + buttonWidth, posy                }}})
    gl.Text(string.format('\255\255\255\1Click to take %d abandoned units !', takeableCount), posx + 0.5 * buttonWidth, posy + 0.5 * buttonHeight, 20, 'ocv')
end

function widget:MousePress(mx, my, mButton)
    if takeableCount > 0 and mButton == 1 then
        local posx, posy = GetButtonPosition()
        if mx >= posx and mx < posx + buttonWidth and
           my >= posy and my < posy + buttonHeight then
            Spring.SendCommands('luarules take2')
            return true
        end
    end
end
