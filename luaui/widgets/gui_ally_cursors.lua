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
		name	= "Ally Cursors - dev",
		desc	= "Shows the mouse pos of players and specs (try: /allycursors_names  _specs  _scaling  _namesfade)",
		author	= "Floris,jK,TheFatController",
		date	= "Apr,2009",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Console commands:

-- allycursors_names
-- allycursors_specs
-- allycursors_scaling
-- allycursors_namesfade

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- configs

local cursorSize				= 11

local hideSpecs					= false

local drawNames					= true
local drawNamesScaling			= true		-- scale up when camera is more distant
local drawNamesFade				= true
local NameFadeStartDistance		= 4800
local NameFadeEndDistance		= 6600

local drawNamesCursorSize		= 7
local fontSizePlayer			= 15
local fontSizeSpec				= 12.5
local sendPacketEvery			= 0.8
local numMousePos				= 2 --//num mouse pos in 1 packet

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local pairs					= pairs

local spGetGroundHeight		= Spring.GetGroundHeight
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spGetTeamColor		= Spring.GetTeamColor
local spIsSphereInView		= Spring.IsSphereInView
local spGetCameraPosition	= Spring.GetCameraPosition

local alliedCursorsPos		= {}
local teamColors			= {}
local notIdle				= {}
local usedCursorSize		= cursorSize
local color,time,wx,wz,lastUpdateDiff,scale,iscale,fscale,gy --keep memory always allocated for these since they are referenced so frequently

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:Initialize()
	widgetHandler:RegisterGlobal('MouseCursorEvent', MouseCursorEvent)
	
	if drawNames then
		usedCursorSize = drawNamesCursorSize
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
		
		acp[(numMousePos+1)*2+1] = os.clock()
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

		acp[(numMousePos+1)*2+1] = os.clock()
		acp[(numMousePos+1)*2+2] = playerPosList[#playerPosList].click
		_,_,_,acp[(numMousePos+1)*2+3] = spGetPlayerInfo(playerID)
	end
end

--------------------------------------------------------------------------------
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



function widget:DrawWorldPreUnit()
	gl.DepthTest(GL.ALWAYS)
	gl.Texture(LUAUI_DIRNAME..'Images/allycursor.png')
	gl.PolygonOffset(-7,-10)
	time = os.clock()
	
	local camX,camY,camZ = spGetCameraPosition()
	
	for playerID,data in pairs(alliedCursorsPos) do 
		name,_,spec,teamID = spGetPlayerInfo(playerID)
		
		wx,wz = data[1],data[2]
		lastUpdatedDiff = time-data[#data-2] + 0.025
		
		if (lastUpdatedDiff<sendPacketEvery) then
			scale  = (1-(lastUpdatedDiff/sendPacketEvery))*numMousePos
			iscale = math.min(math.floor(scale),numMousePos-1)
			fscale = scale-iscale
			wx = CubicInterpolate2(data[iscale*2+1],data[(iscale+1)*2+1],fscale)
			wz = CubicInterpolate2(data[iscale*2+2],data[(iscale+1)*2+2],fscale)
		end
		
		if notIdle[playerID] then
			--draw a cursor
			local gy = spGetGroundHeight(wx,wz)
			if (spIsSphereInView(wx,gy,wz,usedCursorSize)) then
				SetTeamColor(teamID,playerID,1)
				if not spec     or    not drawNames and spec and not hideSpecs then
					local quadSize = usedCursorSize
					if spec then
						quadSize = usedCursorSize * 0.77
					end
					if drawNames then
						gl.Texture(LUAUI_DIRNAME..'Images/allycursor.png')
						gl.BeginEnd(GL.QUADS,DrawGroundquad,wx,gy,wz,quadSize)
						gl.Texture(false)
					else
						gl.BeginEnd(GL.QUADS,DrawGroundquad,wx,gy,wz,quadSize)
					end
				end
				
				--draw nickname
				if drawNames then
					gl.PushMatrix()
					gl.Translate(wx, gy, wz)
					gl.Billboard()
					
					local opacityMultiplier = 1
					if drawNamesFade and camZ   or   drawNamesScaling and camZ then
						local xDifference = camX - wx
						local yDifference = camY - gy
						local zDifference = camZ - wz
						local camDistance = math.sqrt(xDifference*xDifference + yDifference*yDifference + zDifference*zDifference)
						
						if drawNamesScaling then
							local glScale = 0.83 + camDistance / 3000
							gl.Scale(glScale,glScale,glScale)
						end
						if drawNamesFade and camDistance > NameFadeStartDistance then 
							local fadeDistance = NameFadeEndDistance - NameFadeStartDistance
							opacityMultiplier = opacityMultiplier - ((camDistance - NameFadeStartDistance) / fadeDistance)
						end
					end
					if opacityMultiplier then
						if spec then
							if not hideSpecs then
								gl.Color(1,1,1,0.55*opacityMultiplier)
								gl.Text(name, 0, 0, fontSizeSpec, "cn")
							end
						else
							local verticalOffset = usedCursorSize + 8
							local horizontalOffset = usedCursorSize + 1
							-- text shadow
							gl.Color(0,0,0,0.62*opacityMultiplier)
							gl.Text(name, horizontalOffset-(fontSizePlayer/45), verticalOffset-(fontSizePlayer/38), fontSizePlayer, "n")
							gl.Text(name, horizontalOffset+(fontSizePlayer/45), verticalOffset-(fontSizePlayer/38), fontSizePlayer, "n")
							-- text
							gl.Color(teamColors[playerID][1],teamColors[playerID][2],teamColors[playerID][3],0.75*opacityMultiplier)
							gl.Text(name, horizontalOffset, verticalOffset, fontSizePlayer, "n")
						end
					end
					gl.PopMatrix()
				end
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

	gl.PolygonOffset(false)
	gl.Texture(false)
	gl.DepthTest(false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- (console) commands
function widget:TextCommand(command)
    if (string.find(command, "allycursors_names") == 1	and  string.len(command) == 17) then drawNames = not drawNames end
    if (string.find(command, "allycursors_specs") == 1  and  string.len(command) == 17) then hideSpecs = not hideSpecs end
    if (string.find(command, "allycursors_scaling") == 1  and  string.len(command) == 19) then drawNamesScaling = not drawNamesScaling end
    if (string.find(command, "allycursors_namesfade") == 1  and  string.len(command) == 21) then drawNamesFade = not drawNamesFade end
    
	if drawNames then
		usedCursorSize = drawNamesCursorSize
	end
end

-- save data
function widget:GetConfigData(data)
    savedTable = {}
    savedTable.drawNames		= drawNames
    savedTable.hideSpecs		= hideSpecs
    savedTable.drawNamesScaling	= drawNamesScaling
    savedTable.drawNamesFade	= drawNamesFade
    return savedTable
end

-- restore data
function widget:SetConfigData(data)
    if data.drawNames ~= nil			then  drawNames			= data.drawNames end
    if data.hideSpecs ~= nil			then  hideSpecs			= data.hideSpecs end
    if data.drawNamesScaling ~= nil		then  drawNamesScaling	= data.drawNamesScaling end
    if data.drawNamesFade ~= nil		then  drawNamesFade		= data.drawNamesFade end
	
	if drawNames then
		usedCursorSize = drawNamesCursorSize
	end
end
