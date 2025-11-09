local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Mapmarks FX",
      desc      = "Adds glow/rings at map marks",
      author    = "Floris",
      date      = "7 june 2015",
      license   = "GNU GPL, v2 or later",
      layer     = 2,
      enabled   = true,
   }
end


-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

local commands					= {}
local mapDrawNicknameTime		= {}	-- this table is used to filter out previous map drawing nicknames if user has drawn something new
local mapEraseNicknameTime		= {}

local ownPlayerID = Spring.GetMyPlayerID()
local vsx,vsy = spGetViewGeometry()

-- spring vars
local spGetPlayerInfo			= Spring.GetPlayerInfo
local spGetTeamColor			= Spring.GetTeamColor

local glCreateList				= gl.CreateList
local glDeleteList				= gl.DeleteList
local glCallList				= gl.CallList

local commandCount = 0
local glowDlist, font, chobbyInterface, ringDlist, pencilDlist, eraserDlist

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local nicknameOpacityMultiplier	= 6		-- multiplier applied to the given color opacity of the type: 'map_draw'

local generalSize 				= 28		-- overall size
local generalOpacity 			= 0.8		-- overall opacity
local generalDuration			= 1.2		-- overall duration

local ringStartSize				= 9
local ringScale					= 0.75

local imageDir					= ":n:LuaUI/Images/mapmarksfx/"

local types = {
	map_mark = {
		size			= 3.2,
		endSize			= 2.25,
		duration		= 14,
		glowColor		= {1.00 ,1.00 ,1.00 ,0.20},
		ringColor		= {1.00 ,1.00 ,1.00 ,0.75}
	},
	map_draw = {
		size			= 0.75,
		endSize			= 0.2,
		duration		= 2,
		glowColor		= {1.00 ,1.00 ,1.00 ,0.15},
		ringColor		= {1.00 ,1.00 ,1.00 ,0.00}
	},
	map_erase = {
		size			= 3.5,
		endSize			= 0.7,
		duration		= 4,
		glowColor		= {1.00 ,1.00 ,1.00 ,0.10},
		ringColor		= {1.00 ,1.00 ,1.00 ,0.00}
	}
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawGroundquad(x,y,z,size)
	gl.TexCoord(0,0)
	gl.Vertex(x-size,y,z-size)
	gl.TexCoord(0,1)
	gl.Vertex(x-size,y,z+size)
	gl.TexCoord(1,1)
	gl.Vertex(x+size,y,z+size)
	gl.TexCoord(1,0)
	gl.Vertex(x+size,y,z-size)
end


local function AddEffect(cmdType, x, y, z, osClock, unitID, playerID)
	if not playerID then
		playerID = false
	end
	local nickname,_,spec,teamID = spGetPlayerInfo(playerID,false)
	nickname = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or nickname
	local teamcolor = {}
	teamcolor[1],teamcolor[2],teamcolor[3] = spGetTeamColor(teamID)

	commandCount = commandCount + 1
	commands[commandCount] = {
		cmdType		= cmdType,
		x			= x,
		y			= y,
		z			= z,
		osClock		= osClock,
		playerID	= playerID,
		color		= teamcolor,
		spec		= spec,
		nickname	= nickname
	}
end


function widget:ViewResize()
	vsx,vsy = spGetViewGeometry()
	font = WG['fonts'].getFont(1, 1.5)
end


function widget:Initialize()

	glowDlist = glCreateList(function()
		gl.Texture(imageDir..'glow.dds')
		gl.BeginEnd(GL.QUADS,DrawGroundquad,0,0,0,1)
		gl.Texture(false)
	end)
	pencilDlist = glCreateList(function()
		gl.Texture(imageDir..'pencil.dds')
		gl.BeginEnd(GL.QUADS,DrawGroundquad,0,0,0,1)
		gl.Texture(false)
	end)
	eraserDlist = glCreateList(function()
		gl.Texture(imageDir..'eraser.dds')
		gl.BeginEnd(GL.QUADS,DrawGroundquad,0,0,0,1)
		gl.Texture(false)
	end)
	ringDlist = glCreateList(function()
		gl.Texture(imageDir..'ring.dds')
		gl.BeginEnd(GL.QUADS,DrawGroundquad,0,0,0,1)
		gl.Texture(false)
	end)

	widget:ViewResize()
end


function widget:Shutdown()
	glDeleteList(glowDlist)
	glDeleteList(pencilDlist)
	glDeleteList(eraserDlist)
	glDeleteList(ringDlist)
end

function widget:MapDrawCmd(playerID, cmdType, x, y, z, a, b, c)
	local osClock = os.clock()
	if cmdType == 'point' then
		AddEffect('map_mark', x, y, z, osClock, false, playerID)
	elseif cmdType == 'line' then
		mapDrawNicknameTime[playerID] = osClock
		AddEffect('map_draw', x, y, z, osClock, false, playerID)
	elseif cmdType == 'erase' then
		mapEraseNicknameTime[playerID] = osClock
		AddEffect('map_erase', x, y, z, osClock, false, playerID)
	end
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:ClearMapMarks()
	commands = {}
end

function widget:DrawWorldPreUnit()
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then return end
	if WG.clearmapmarks and WG.clearmapmarks.continuous then return end

	local osClock = os.clock()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(false)
	gl.PushMatrix()

	local duration, durationProcess, size, a, glowColor, ringColor, aRing, ringSize, iconSize

	for cmdKey, cmdValue in pairs(commands) do

		duration		= types[cmdValue.cmdType].duration * generalDuration
		durationProcess = (osClock - cmdValue.osClock) / duration

		-- remove when duration has passed
		if osClock - cmdValue.osClock > duration  then

			commands[cmdKey] = nil

		-- remove nicknames when user has drawn something new
		elseif  cmdValue.cmdType == 'map_draw'  and  mapDrawNicknameTime[cmdValue.playerID] ~= nil  and  cmdValue.osClock < mapDrawNicknameTime[cmdValue.playerID] then

			commands[cmdKey] = nil

		-- draw all
		elseif  types[cmdValue.cmdType].glowColor[4] > 0  or  types[cmdValue.cmdType].ringColor[4] > 0  then
			size	= generalSize * types[cmdValue.cmdType].size   +   ((generalSize * types[cmdValue.cmdType].endSize - generalSize * types[cmdValue.cmdType].size) * durationProcess)
			a		= (1 - durationProcess) * generalOpacity

			if cmdValue.spec then
				glowColor = {1,1,1,types[cmdValue.cmdType].glowColor[4]}
				ringColor = {1,1,1,types[cmdValue.cmdType].ringColor[4]}
			else
				glowColor = {cmdValue.color[1],cmdValue.color[2],cmdValue.color[3],types[cmdValue.cmdType].glowColor[4]}
				ringColor = {cmdValue.color[1],cmdValue.color[2],cmdValue.color[3],types[cmdValue.cmdType].ringColor[4]}
			end

			aRing	= a * ringColor[4]
			a		= a * glowColor[4]


			gl.Translate(cmdValue.x, cmdValue.y, cmdValue.z)

			-- glow
			if glowColor[4] > 0 then
				gl.Color(glowColor[1],glowColor[2],glowColor[3],a)
				gl.Scale(size*0.8,1,size*0.8)
				glCallList(glowDlist)
				gl.Scale(1/(size*0.8),1,1/(size*0.8))
			end
			-- ring
			if aRing > 0 then
				gl.Color(ringColor[1],ringColor[2],ringColor[3],aRing)
				ringSize = ringStartSize + (size * ringScale) * durationProcess
				gl.Scale(ringSize,1,ringSize)
				glCallList(ringDlist)
				gl.Scale(1/ringSize,1,1/ringSize)
			end

			-- draw + erase:   nickname / draw icon
			if  cmdValue.playerID  and  cmdValue.playerID ~= ownPlayerID  and   (cmdValue.cmdType == 'map_draw'  or    cmdValue.cmdType == 'map_erase' and  cmdValue.osClock >= mapEraseNicknameTime[cmdValue.playerID]) then

				if (cmdValue.spec) then
					iconSize = 11
					gl.Color(glowColor[1],glowColor[2],glowColor[3], a * nicknameOpacityMultiplier)

					if cmdValue.cmdType == 'map_draw' then
						gl.Scale(iconSize,1,iconSize)
						glCallList(pencilDlist)
						gl.Scale(1/iconSize,1,1/iconSize)
					else
						gl.Scale(iconSize,1,iconSize)
						glCallList(eraserDlist)
						gl.Scale(1/iconSize,1,1/iconSize)
					end

					gl.PushMatrix()
					gl.Billboard()
					font:Begin()
					font:Print(cmdValue.nickname, 0, -28, 20, "cn")
					font:End()
					gl.PopMatrix()
				end
			end

			gl.Translate(-cmdValue.x, -cmdValue.y, -cmdValue.z)
		end
	end

	gl.PopMatrix()
	gl.Color(1,1,1,1)
end

