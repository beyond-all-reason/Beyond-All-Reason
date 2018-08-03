--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	Copyright (C) 2007.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
    return {
        name	= "AllyCursors",
        desc	= "Shows the mouse pos of allied players",
        author	= "Floris,jK,TheFatController",
        date	= "31 may 2015",
        license	= "GNU GPL, v2 or later",
        layer	= 0,
        enabled	= true,
    }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- configs

local cursorSize					= 11
local drawNamesCursorSize			= 8.5

local dlistAmount					= 5		-- number of dlists generated for each player (# available opacity levels)

local sendPacketEvery				= 0.6
local numMousePos					= 2 --//num mouse pos in 1 packet

local showSpectatorName    			= true
local showPlayerName       			= true
local drawNamesScaling				= true
local drawNamesFade					= true

local fontSizePlayer        		= 18
local fontOpacityPlayer     		= 0.68
local fontSizeSpec          		= 14
local fontOpacitySpec       		= 0.48

local NameFadeStartDistance			= 4800
local NameFadeEndDistance			= 7200
local idleCursorTime				= 30		-- fade time cursor (specs only)

-- tweak ui
local buttonsize					= 18
local rowgap						= 6
local leftmargin					= 20
local buttontab						= 200
local vsx, vsy 						= gl.GetViewSizes()
local tweakUiWidth, tweakUiHeight	= 240, 215
local tweakUiPosX, tweakUiPosY		= 500, 550

-- images
local allyCursor      			    = ":n:LuaUI/Images/allycursor.dds"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:TextCommand(command)
    local mycommand = false
    if (string.find(command, "allycursorspecname") == 1  and  string.len(command) == 18) then showSpectatorName = not showSpectatorName end

    if (string.find(command, "allycursorplayername") == 1  and  string.len(command) == 20) then showPlayerName = not showPlayerName end

    if showPlayerName then
        usedCursorSize = drawNamesCursorSize
    end
end

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.showSpectatorName  = showSpectatorName
    savedTable.showPlayerName     = showPlayerName
    return savedTable
end

function widget:SetConfigData(data)
    if data.showSpectatorName ~= nil   then  showSpectatorName   = data.showSpectatorName end
    if data.showPlayerName ~= nil      then  showPlayerName      = data.showPlayerName end
    
    if showPlayerName then
        usedCursorSize = drawNamesCursorSize
    end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetGroundHeight		= Spring.GetGroundHeight
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spGetTeamColor		= Spring.GetTeamColor
local spIsSphereInView		= Spring.IsSphereInView
local spGetCameraPosition	= Spring.GetCameraPosition
local spGetCameraDirection	= Spring.GetCameraDirection
local spIsGUIHidden         = Spring.IsGUIHidden

local glCreateList			= gl.CreateList
local glDeleteList			= gl.DeleteList
local glCallList			= gl.CallList

local floor					= math.floor
local min					= math.min
local diag					= math.diag
local GL_QUADS				= GL.QUADS
local clock					= os.clock
local Button				= {}
local Panel					= {}
local alliedCursorsPos      = {}
local prevCursorPos			= {}
local alliedCursorsTime		= {}		-- for API purpose
local usedCursorSize		= cursorSize
local prevMouseX,prevMouseY = 0
local allycursorDrawList	= {}
local myPlayerID            = Spring.GetMyPlayerID()


local specList = {}
function updateSpecList()
    specList = {}
    local t = Spring.GetPlayerList()
    for _,playerID in ipairs(t) do
        local _,_,spec = spGetPlayerInfo(playerID)
        specList[playerID] = spec
    end
end

function widget:Initialize()
    widgetHandler:RegisterGlobal('MouseCursorEvent', MouseCursorEvent)
    
    if showPlayerName then
        usedCursorSize = drawNamesCursorSize
    end
    updateSpecList()
    
    WG['allycursor_api'] = {}
    WG['allycursor_api'].GetCursorTimes = function()
        return alliedCursorsTime
    end
    
    local now = clock()
    local pList = Spring.GetPlayerList()
    for _,playerID in ipairs(pList) do
        alliedCursorsTime[playerID] = now
    end
end


function widget:Shutdown()
    widgetHandler:DeregisterGlobal('MouseCursorEvent')
    for playerID, dlists in pairs(allycursorDrawList) do
        for opacityMultiplier, dlist in pairs(dlists) do
            gl.DeleteList(allycursorDrawList[playerID][opacityMultiplier])
        end
    end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CubicInterpolate2(x0,x1,mix)
    local mix2 = mix*mix;
    local mix3 = mix2*mix;

    return x0*(2*mix3-3*mix2+1) + x1*(3*mix2-2*mix3);
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local playerPos = {}
function MouseCursorEvent(playerID,x,z,click)
    if myPlayerID == playerID then
        return true
    end
    local playerPosList = playerPos[playerID] or {}
    playerPosList[#playerPosList+1] = {x=x,z=z,click=click}
    playerPos[playerID] = playerPosList
    if #playerPosList < numMousePos then
        return
    end
    playerPos[playerID] = {}
    
    if alliedCursorsPos[playerID] then
        local acp = alliedCursorsPos[playerID]

        acp[(numMousePos)*2+1]   = acp[1]
        acp[(numMousePos)*2+2]   = acp[2]

        for i=0,numMousePos-1 do
            acp[i*2+1] = playerPosList[i+1].x
            acp[i*2+2] = playerPosList[i+1].z
        end

        acp[(numMousePos+1)*2+1] = clock()
        acp[(numMousePos+1)*2+2] = playerPosList[#playerPosList].click
    else
        local acp = {}
        alliedCursorsPos[playerID] = acp

        for i=0,numMousePos-1 do
            acp[i*2+1] = playerPosList[i+1].x
            acp[i*2+2] = playerPosList[i+1].z
        end

        acp[(numMousePos)*2+1]   = playerPosList[(numMousePos-2)*2+1].x
        acp[(numMousePos)*2+2]   = playerPosList[(numMousePos-2)*2+1].z

        acp[(numMousePos+1)*2+1] = clock()
        acp[(numMousePos+1)*2+2] = playerPosList[#playerPosList].click
        _,_,_,acp[(numMousePos+1)*2+3] = spGetPlayerInfo(playerID)
    end
    
    
    -- check if there has been changes
    wx,wz = alliedCursorsPos[playerID][1*2+1],alliedCursorsPos[playerID][1*2+1]
    
    if prevCursorPos[playerID] == nil or wx ~= prevCursorPos[playerID].wx or wz ~= prevCursorPos[playerID].wz then
        alliedCursorsTime[playerID] = clock()
    end
    
    if prevCursorPos[playerID] == nil then
        prevCursorPos[playerID] = {}
    end
    prevCursorPos[playerID].wx = wx
    prevCursorPos[playerID].wz = wz
end

--------------------------------------------------------------------------------

local function DrawGroundquad(wx,gy,wz,size)
    gl.TexCoord(0,0)
    gl.Vertex(wx-size,gy+size,wz-size)
    gl.TexCoord(0,1)
    gl.Vertex(wx-size,gy+size,wz+size)
    gl.TexCoord(1,1)
    gl.Vertex(wx+size,gy+size,wz+size)
    gl.TexCoord(1,0)
    gl.Vertex(wx+size,gy+size,wz-size)
end

local teamColors = {}
local color
local time,wx,wz,lastUpdateDiff,scale,iscale,fscale,gy --keep memory always allocated for these since they are referenced so frequently
local notIdle = {}

local function SetTeamColor(teamID,playerID,a)
    color = teamColors[playerID]
    if color then
        gl.Color(color[1],color[2],color[3],color[4]*a)
        return
    end
    
    --make color
    local r, g, b = spGetTeamColor(teamID)
    if specList[playerID] then
        color = {1, 1, 1, 0.6}
    elseif r and g and b then
        color = {r, g, b, 0.75}
    end
    teamColors[playerID] = color
    gl.Color(color)
    return
end

local sec = 0
local updateTime = 2
function widget:Update(dt)
    sec = sec+dt
    if sec > updateTime then
        sec = 0
        updateSpecList()
    end
end


function widget:PlayerChanged(playerID)
    local _, _, isSpec, teamID = spGetPlayerInfo(playerID)
    specList[playerID] = isSpec
    local r, g, b = spGetTeamColor(teamID)
    local color
    if isSpec then
        color = {1, 1, 1, 0.6}
    elseif r and g and b then
        color = {r, g, b, 0.75}
    end
    teamColors[playerID] = color
    allycursorDrawList[playerID] = nil
end
function widget:PlayerAdded(playerID)
    widget:PlayerChanged(playerID)
end
function widget:PlayerRemoved(playerID, reason)
    specList[playerID] = nil
end


function createCursorDrawList(playerID, opacityMultiplier)
    local name,_,spec,teamID = spGetPlayerInfo(playerID)
    local r, g, b = spGetTeamColor(teamID)
    local wx,gy,wz = 0,0,0
    local quadSize = usedCursorSize
    if spec then
        quadSize = usedCursorSize * 0.77
    end

    SetTeamColor(teamID,playerID,1)

    if not spec  and not showPlayerName    or    spec  and  not showSpectatorName  then
        --draw a cursor
        gl.Texture(allyCursor)
        gl.BeginEnd(GL.QUADS,DrawGroundquad,wx,gy,wz,quadSize)
        gl.Texture(false)
    else
        if not spec then
            --draw a cursor
            gl.Texture(allyCursor)
            gl.BeginEnd(GL.QUADS,DrawGroundquad,wx,gy,wz,quadSize)
            gl.Texture(false)
        end
        
        --draw the nickname
        gl.PushMatrix()
        gl.Translate(wx, gy, wz)
        gl.Rotate(-90,1,0,0)
        
        if spec then
            gl.Color(1,1,1,fontOpacitySpec*opacityMultiplier)
            gl.Text(name, 0, 0, fontSizeSpec, "cn")
        else
            local verticalOffset = usedCursorSize + 8
            local horizontalOffset = usedCursorSize + 1
            -- text shadow
            gl.Color(0,0,0,fontOpacityPlayer*0.62*opacityMultiplier)
            gl.Text(name, horizontalOffset-(fontSizePlayer/50), verticalOffset-(fontSizePlayer/42), fontSizePlayer, "n")
            gl.Text(name, horizontalOffset+(fontSizePlayer/50), verticalOffset-(fontSizePlayer/42), fontSizePlayer, "n")
            -- text
            gl.Color(r,g,b,fontOpacityPlayer*opacityMultiplier)
            gl.Text(name, horizontalOffset, verticalOffset, fontSizePlayer, "n")
        end
        gl.PopMatrix()
    end   
end

    

local camDistance, glScale

local function DrawCursor(playerID,wx,wz,camX,camY,camZ,opacity)
	local gy = spGetGroundHeight(wx,wz)
	if not (spIsSphereInView(wx,gy,wz,usedCursorSize)) then
		return 
	end

	--calc scale
	camDistance = diag(camX-wx, camY-gy, camZ-wz) 
	glScale = 0.83 + camDistance / 5000

	-- calc opacity
	local opacityMultiplier = 1
	if drawNamesFade and camDistance > NameFadeStartDistance then 
		opacityMultiplier = (1 - (camDistance-NameFadeStartDistance) / (NameFadeEndDistance-NameFadeStartDistance))
		if opacityMultiplier > 1 then
			opacityMultiplier = 1
		end
	end

	if opacity >= 1 then
		opacityMultiplier = math.floor(opacityMultiplier * dlistAmount)/dlistAmount
	else	-- if (spec and) fading out due to idling
		opacityMultiplier = math.floor(opacityMultiplier * (opacity * dlistAmount))/dlistAmount
	end
	
	if opacityMultiplier > 0.11 then
		if allycursorDrawList[playerID] == nil then 
			allycursorDrawList[playerID] = {}
		end
		if allycursorDrawList[playerID][opacityMultiplier] == nil then
			allycursorDrawList[playerID][opacityMultiplier] = glCreateList(createCursorDrawList, playerID, opacityMultiplier)
		end

		local rotValue = 0
		gl.PushMatrix()
		gl.Translate(wx, gy, wz)
		gl.Rotate(rotValue,0,1,0)
		if drawNamesScaling then
			gl.Scale(glScale,0,glScale)
		end
		glCallList(allycursorDrawList[playerID][opacityMultiplier])
		if drawNamesScaling then
			gl.Scale(-glScale,0,-glScale)
		end
		gl.PopMatrix()
	end
end

function widget:DrawWorldPreUnit()
    if spIsGUIHidden() then return end
    gl.DepthTest(GL.ALWAYS)
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    gl.PolygonOffset(-7,-10)
    time = clock()
    
    local camX,camY,camZ = spGetCameraPosition()
    --local camRotX, camRotY, camRotZ = spGetCameraDirection()		-- x is fucked when springstyle camera tries to stay/snap angularly
    --Spring.Echo(camRotX.."   "..camRotY.."   "..camRotZ)
    for playerID,data in pairs(alliedCursorsPos) do 
        local wx,wz = data[1],data[2]
        local lastUpdatedDiff = time-data[#data-2] + 0.025

        if (lastUpdatedDiff<sendPacketEvery) then
            local scale  = (1-(lastUpdatedDiff/sendPacketEvery))*numMousePos
            local iscale = min(floor(scale),numMousePos-1)
            local fscale = scale-iscale
            wx = CubicInterpolate2(data[iscale*2+1],data[(iscale+1)*2+1],fscale)
            wz = CubicInterpolate2(data[iscale*2+2],data[(iscale+1)*2+2],fscale)
        end

        if notIdle[playerID] and alliedCursorsTime[playerID] > (time-idleCursorTime) then
            local opacity = 1
            if specList[playerID] then
                opacity = 1 - ((time - alliedCursorsTime[playerID]) / idleCursorTime)
                if opacity > 1 then opacity = 1 end
            end
            if opacity > 0.1 then
                DrawCursor(playerID,wx,wz,camX,camY,camZ,opacity)
            end
        else
            --mark a player as notIdle as soon as they move (and keep them always set notIdle after this)
            if wx and wz and wz_old and wz_old and(math.abs(wx_old-wx)>=1 or math.abs(wz_old-wz)>=1) then --math.abs is needed because of floating point used in interpolation
              notIdle[playerID] = true
              wx_old = nil
              wz_old = nil
            else
              wx_old = wx
              wz_old = wz
            end

        end
    end
    --gl.EndText
    gl.PolygonOffset(false)
    gl.Texture(false)
    gl.DepthTest(false)
end

