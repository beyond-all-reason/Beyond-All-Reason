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
		name	= "Ally Cursors",
		desc	= "Shows the mouse position of other players",
		author	= "jK,TheFatController",
		date	= "Apr,2009",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- configs

local sendPacketEvery		= 0.8
local numMousePos			= 2 --//num mouse pos in 1 packet
local numTrails				= 2 --//must be >= 1

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- locals

local pairs					= pairs

local GetGameFrame			= Spring.GetGameFrame
local GetGroundHeight		= Spring.GetGroundHeight
local GetPlayerInfo			= Spring.GetPlayerInfo
local GetTeamColor			= Spring.GetTeamColor
local IsSphereInView		= Spring.IsSphereInView
local GetSpectatingState	= Spring.GetSpectatingState
local GetMyPlayerID			= Spring.GetMyPlayerID
local GetMyTeamID 	 		= Spring.GetMyTeamID

local glTexCoord			= gl.TexCoord
local glVertex				= gl.Vertex
local glPolygonOffset		= gl.PolygonOffset
local glDepthTest			= gl.DepthTest
local glTexture				= gl.Texture
local glColor				= gl.Color
local glBeginEnd			= gl.BeginEnd
local GL_ALWAYS				= GL.ALWAYS

local floor					= math.floor
local min					= math.min
local GL_QUADS				= GL.QUADS

local clock					= os.clock

local alliedCursorsPos = {}


function widget:Initialize()
	widgetHandler:RegisterGlobal('MouseCursorEvent', MouseCursorEvent)
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
		_,_,_,acp[(numMousePos+1)*2+3] = GetPlayerInfo(playerID)
	end
end

--------------------------------------------------------------------------------

local QSIZE = 12

local function DrawGroundquad(wx,gy,wz)
	glTexCoord(0,0)
	glVertex(wx-QSIZE,gy+12,wz-QSIZE)
	glTexCoord(0,1)
	glVertex(wx-QSIZE,gy+12,wz+QSIZE)
	glTexCoord(1,1)
	glVertex(wx+QSIZE,gy+12,wz+QSIZE)
	glTexCoord(1,0)
	glVertex(wx+QSIZE,gy+12,wz-QSIZE)
end


local teamColors = {}
local color
local time,wx,wz,lastUpdateDiff,scale,iscale,fscale,gy --keep memory always allocated for these since they are referenced so frequently
local notIdle = {}

local function SetTeamColor(teamID,playerID,a)
	color = teamColors[playerID]
	if color then
		glColor(color[1],color[2],color[3],color[4]*a/numTrails)
		return
	end
	
	--make color
	local r, g, b = Spring.GetTeamColor(teamID)
	local _, _, isSpec = GetPlayerInfo(playerID)
	if isSpec then
		color = {1, 1, 1, 0.6}
	elseif r and g and b then
		color = {r, g, b, 0.75}
	end
	teamColors[playerID] = color
	glColor(color)
	return
end


function widget:PlayerChanged(playerID)
	local _, _, isSpec, teamID = GetPlayerInfo(playerID)
	local r, g, b = Spring.GetTeamColor(teamID)
	local color
	if isSpec then
		color = {1, 1, 1, 0.6}
	elseif r and g and b then
		color = {r, g, b, 0.75}
	end
	teamColors[playerID] = color
end



function widget:DrawWorldPreUnit()
	glDepthTest(GL_ALWAYS)
	glTexture('LuaUI/Images/AlliedCursors.png')
	glPolygonOffset(-7,-10)
	time = clock()
	for playerID,data in pairs(alliedCursorsPos) do 
		teamID = data[#data]
		for n=0,numTrails do
			wx,wz = data[1],data[2]
			lastUpdatedDiff = time-data[#data-2] + 0.025 * n
			
			if (lastUpdatedDiff<sendPacketEvery) then
				scale  = (1-(lastUpdatedDiff/sendPacketEvery))*numMousePos
				iscale = min(floor(scale),numMousePos-1)
				fscale = scale-iscale
				wx = CubicInterpolate2(data[iscale*2+1],data[(iscale+1)*2+1],fscale)
				wz = CubicInterpolate2(data[iscale*2+2],data[(iscale+1)*2+2],fscale)
			end
			
			if notIdle[playerID] then
				--draw a cursor
				gy = GetGroundHeight(wx,wz)
				if (IsSphereInView(wx,gy,wz,QSIZE)) then
					SetTeamColor(teamID,playerID,n)
					glBeginEnd(GL_QUADS,DrawGroundquad,wx,gy,wz)
				end
			else
				--mark a player as notIdle as soon as they move (and keep them always set notIdle after this)
				if (n~=0) and wx and wz and wz_old and wz_old and(math.abs(wx_old-wx)>=1 or math.abs(wz_old-wz)>=1) then --math.abs is needed because of floating point used in interpolation
					notIdle[playerID] = true
					wx_old = nil
					wz_old = nil
				else
					wx_old = wx
					wz_old = wz
				end
			end
			
		end
	end

	glPolygonOffset(false)
	glTexture(false)
	glDepthTest(false)
end       				

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
