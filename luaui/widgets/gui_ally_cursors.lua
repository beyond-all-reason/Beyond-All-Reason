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

local dlistAmount					= 3		-- number of dlists generated for each player (# available opacity levels)

local sendPacketEvery				= 0.8
local numMousePos					= 2 --//num mouse pos in 1 packet

local showSpectatorName    			= true
local showPlayerName       			= true
local drawNamesScaling				= true
local drawNamesFade					= true

local fontSizePlayer        		= 18
local fontOpacityPlayer     		= 0.65
local fontSizeSpec          		= 14
local fontOpacitySpec       		= 0.40

local NameFadeStartDistance			= 4800
local NameFadeEndDistance			= 7200

-- tweak ui
local buttonsize					= 18
local rowgap						= 6
local leftmargin					= 20
local buttontab						= 200
local vsx, vsy 						= gl.GetViewSizes()
local tweakUiWidth, tweakUiHeight	= 240, 215
local tweakUiPosX, tweakUiPosY		= 500, 550

-- images
local allyCursor      			    = ":n:"..LUAUI_DIRNAME.."Images/allycursor.dds"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:TextCommand(command)
    local mycommand = false
    if (string.find(command, "allycursorspecname") == 1  and  string.len(command) == 18) then showSpectatorName = not showSpectatorName end

    if (string.find(command, "allycursorplayername") == 1  and  string.len(command) == 20) then showPlayerName = not showPlayerName end

    if (string.find(command, "+allycursorspecfontsize") == 1) then fontSizeSpec = fontSizeSpec + 1.5 end
    if (string.find(command, "-allycursorspecfontsize") == 1) then fontSizeSpec = fontSizeSpec - 1.5 end

    if (string.find(command, "+allycursorspecfontopacity") == 1) then fontOpacitySpec = fontOpacitySpec + 0.05 end
    if (string.find(command, "-allycursorspecfontopacity") == 1) then fontOpacitySpec = fontOpacitySpec - 0.05 end

    if (string.find(command, "+allycursorplayerfontsize") == 1) then fontSizePlayer = fontSizePlayer + 1.5 end
    if (string.find(command, "-allycursorplayerfontsize") == 1) then fontSizePlayer = fontSizePlayer - 1.5 end

    if (string.find(command, "+allycursorplayerfontopacity") == 1) then fontOpacityPlayer = fontOpacityPlayer + 0.05 end
    if (string.find(command, "-allycursorplayerfontopacity") == 1) then fontOpacityPlayer = fontOpacityPlayer - 0.05 end

    if fontOpacitySpec > 1 then fontOpacitySpec = 1 end if fontOpacitySpec < 0.15 then fontOpacitySpec = 0.15 end
    if fontOpacityPlayer > 1 then fontOpacityPlayer = 1 end if fontOpacityPlayer < 0.15 then fontOpacityPlayer = 0.15 end
    if fontSizeSpec > 60 then fontSizeSpec = 60 end if fontSizeSpec < 10 then fontSizeSpec = 10 end
    if fontSizePlayer > 60 then fontSizePlayer = 60 end if fontSizePlayer < 10 then fontSizePlayer = 10 end
    
    if showPlayerName then
        usedCursorSize = drawNamesCursorSize
    end
end

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.showSpectatorName  = showSpectatorName
    savedTable.showPlayerName     = showPlayerName
    savedTable.useTeamColor       = useTeamColor
    savedTable.fontSizePlayer     = fontSizePlayer
    savedTable.fontOpacityPlayer  = fontOpacityPlayer
    savedTable.fontSizeSpec       = fontSizeSpec
    savedTable.fontOpacitySpec    = fontOpacitySpec
    return savedTable
end

function widget:SetConfigData(data)
    if data.showSpectatorName ~= nil   then  showSpectatorName   = data.showSpectatorName end
    if data.showPlayerName ~= nil      then  showPlayerName      = data.showPlayerName end
    if data.useTeamColor ~= nil        then  useTeamColor        = data.useTeamColor end
    fontSizePlayer        = data.fontSizePlayer     or fontSizePlayer
    fontOpacityPlayer     = data.fontOpacityPlayer  or fontOpacityPlayer
    fontSizeSpec          = data.fontSizeSpec       or fontSizeSpec
    fontOpacitySpec       = data.fontOpacitySpec    or fontOpacitySpec
    
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
local camRotX, camRotY, camRotZ = spGetCameraDirection()


function widget:Initialize()
    widgetHandler:RegisterGlobal('MouseCursorEvent', MouseCursorEvent)
    
    if showPlayerName then
        usedCursorSize = drawNamesCursorSize
    end
    
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
    local _, _, isSpec = spGetPlayerInfo(playerID)
    if isSpec then
        color = {1, 1, 1, 0.6}
    elseif r and g and b then
        color = {r, g, b, 0.75}
    end
    teamColors[playerID] = color
    gl.Color(color)
    return
end


function widget:PlayerChanged(playerID)
    local _, _, isSpec, teamID = spGetPlayerInfo(playerID)
    local r, g, b = spGetTeamColor(teamID)
    local color
    if isSpec then
        color = {1, 1, 1, 0.6}
    elseif r and g and b then
        color = {r, g, b, 0.75}
    end
    teamColors[playerID] = color
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
        --gl.Billboard()
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

local function DrawCursor(playerID,wx,wy,camX,camY,camZ)
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
                
    opacityMultiplier = math.floor(opacityMultiplier * dlistAmount)/dlistAmount
            
    if opacityMultiplier > 0.11 then
        if allycursorDrawList[playerID] == nil then 
            allycursorDrawList[playerID] = {}
        end
        if allycursorDrawList[playerID][opacityMultiplier] == nil then
            allycursorDrawList[playerID][opacityMultiplier] = glCreateList(createCursorDrawList, playerID, opacityMultiplier)
        end
        
        --local rotValue = -(camRotX) * 360
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
    camRotX, camRotY, camRotZ = spGetCameraDirection()		-- x is fucked when springstyle camera tries to stay/snap angularly
    --Spring.Echo(camRotX.."   "..camRotY.."   "..camRotZ)
    for playerID,data in pairs(alliedCursorsPos) do 
        name,_,spec,teamID = spGetPlayerInfo(playerID)
        
        wx,wz = data[1],data[2]
        lastUpdatedDiff = time-data[#data-2] + 0.025
        
        if (lastUpdatedDiff<sendPacketEvery) then
            scale  = (1-(lastUpdatedDiff/sendPacketEvery))*numMousePos
            iscale = min(floor(scale),numMousePos-1)
            fscale = scale-iscale
            wx = CubicInterpolate2(data[iscale*2+1],data[(iscale+1)*2+1],fscale)
            wz = CubicInterpolate2(data[iscale*2+2],data[(iscale+1)*2+2],fscale)
        end
        
        if notIdle[playerID] then
            DrawCursor(playerID,wx,wy,camX,camY,camZ)
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

