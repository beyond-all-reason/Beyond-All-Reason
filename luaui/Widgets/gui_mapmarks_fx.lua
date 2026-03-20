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
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamColor = Spring.GetTeamColor

-- Localized gl functions
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glCallList = gl.CallList
local glBlending = gl.Blending
local glDepthTest = gl.DepthTest
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale
local glColor = gl.Color
local glBillboard = gl.Billboard

-- Localized math functions
local osClock = os.clock

-- this table is used to filter out previous map drawing nicknames
-- if user has drawn something new
local commands = {}
local mapDrawNicknameTime = {}
local mapEraseNicknameTime = {}

local ownPlayerID = Spring.GetMyPlayerID()
local vsx,vsy = spGetViewGeometry()

local commandCount = 0
local glowDlist, font, chobbyInterface, ringDlist, pencilDlist, eraserDlist

-- Reusable tables to avoid allocations
local tempGlowColor = {1, 1, 1, 1}
local tempRingColor = {1, 1, 1, 1}

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
		ringColor		= {1.00 ,1.00 ,1.00 ,0.75},
		-- Precalculated values
		sizeScaled = 0,
		endSizeScaled = 0,
		sizeDelta = 0,
	},
	map_draw = {
		size			= 0.75,
		endSize			= 0.2,
		duration		= 2,
		glowColor		= {1.00 ,1.00 ,1.00 ,0.15},
		ringColor		= {1.00 ,1.00 ,1.00 ,0.00},
		-- Precalculated values
		sizeScaled = 0,
		endSizeScaled = 0,
		sizeDelta = 0,
	},
	map_erase = {
		size			= 3.5,
		endSize			= 0.7,
		duration		= 4,
		glowColor		= {1.00 ,1.00 ,1.00 ,0.10},
		ringColor		= {1.00 ,1.00 ,1.00 ,0.00},
		-- Precalculated values
		sizeScaled = 0,
		endSizeScaled = 0,
		sizeDelta = 0,
	}
}

-- Precalculate scaled sizes
for _, typeData in pairs(types) do
	typeData.sizeScaled = generalSize * typeData.size
	typeData.endSizeScaled = generalSize * typeData.endSize
	typeData.sizeDelta = typeData.endSizeScaled - typeData.sizeScaled
end

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


local function AddEffect(cmdType, x, y, z, timestamp, unitID, playerID)
	if not playerID then
		playerID = false
	end
	local nickname,_,spec,teamID = spGetPlayerInfo(playerID,false)
	nickname = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or nickname

	-- Reuse table from pool or create new color table
	local teamcolor = {0, 0, 0}
	teamcolor[1],teamcolor[2],teamcolor[3] = spGetTeamColor(teamID)

	commandCount = commandCount + 1
	commands[commandCount] = {
		cmdType		= cmdType,
		x			= x,
		y			= y,
		z			= z,
		osClock		= timestamp,
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
	local currentTime = osClock()
	if cmdType == 'point' then
		AddEffect('map_mark', x, y, z, currentTime, false, playerID)
	elseif cmdType == 'line' then
		mapDrawNicknameTime[playerID] = currentTime
		AddEffect('map_draw', x, y, z, currentTime, false, playerID)
	elseif cmdType == 'erase' then
		mapEraseNicknameTime[playerID] = currentTime
		AddEffect('map_erase', x, y, z, currentTime, false, playerID)
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

	local currentTime = osClock()
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glDepthTest(false)
	glPushMatrix()

	local duration, durationProcess, size, a, glowColor, ringColor, aRing, ringSize, iconSize
	
	-- Use numeric iteration for better performance
	local i = 1
	while i <= commandCount do
		local cmdValue = commands[i]
		
		if not cmdValue then
			-- Swap with last element and decrease count
			commands[i] = commands[commandCount]
			commands[commandCount] = nil
			commandCount = commandCount - 1
		else
			local typeData = types[cmdValue.cmdType]
			duration = typeData.duration * generalDuration
			durationProcess = (currentTime - cmdValue.osClock) / duration

			-- remove when duration has passed
			if currentTime - cmdValue.osClock > duration then
				commands[i] = commands[commandCount]
				commands[commandCount] = nil
				commandCount = commandCount - 1

			-- remove nicknames when user has drawn something new
			elseif cmdValue.cmdType == 'map_draw' and mapDrawNicknameTime[cmdValue.playerID] ~= nil
				and cmdValue.osClock < mapDrawNicknameTime[cmdValue.playerID] then
				commands[i] = commands[commandCount]
				commands[commandCount] = nil
				commandCount = commandCount - 1

			-- draw all
			elseif typeData.glowColor[4] > 0 or typeData.ringColor[4] > 0 then
				-- Use precalculated values
				size = typeData.sizeScaled + (typeData.sizeDelta * durationProcess)
				a = (1 - durationProcess) * generalOpacity

				-- Reuse tables for colors instead of creating new ones
				if cmdValue.spec then
					tempGlowColor[1] = 1
					tempGlowColor[2] = 1
					tempGlowColor[3] = 1
					tempGlowColor[4] = typeData.glowColor[4]
					tempRingColor[1] = 1
					tempRingColor[2] = 1
					tempRingColor[3] = 1
					tempRingColor[4] = typeData.ringColor[4]
					glowColor = tempGlowColor
					ringColor = tempRingColor
				else
					tempGlowColor[1] = cmdValue.color[1]
					tempGlowColor[2] = cmdValue.color[2]
					tempGlowColor[3] = cmdValue.color[3]
					tempGlowColor[4] = typeData.glowColor[4]
					tempRingColor[1] = cmdValue.color[1]
					tempRingColor[2] = cmdValue.color[2]
					tempRingColor[3] = cmdValue.color[3]
					tempRingColor[4] = typeData.ringColor[4]
					glowColor = tempGlowColor
					ringColor = tempRingColor
				end

				aRing = a * ringColor[4]
				a = a * glowColor[4]

				glTranslate(cmdValue.x, cmdValue.y, cmdValue.z)

				-- glow
				if glowColor[4] > 0 then
					glColor(glowColor[1], glowColor[2], glowColor[3], a)
					local scaleGlow = size * 0.8
					glScale(scaleGlow, 1, scaleGlow)
					glCallList(glowDlist)
					local invScaleGlow = 1 / scaleGlow
					glScale(invScaleGlow, 1, invScaleGlow)
				end
				
				-- ring
				if aRing > 0 then
					glColor(ringColor[1], ringColor[2], ringColor[3], aRing)
					ringSize = ringStartSize + (size * ringScale) * durationProcess
					glScale(ringSize, 1, ringSize)
					glCallList(ringDlist)
					local invRingSize = 1 / ringSize
					glScale(invRingSize, 1, invRingSize)
				end

				-- draw + erase: nickname / draw icon
				if cmdValue.playerID and cmdValue.playerID ~= ownPlayerID then
					if (cmdValue.cmdType == 'map_draw' or
						(cmdValue.cmdType == 'map_erase' and
						cmdValue.osClock >= mapEraseNicknameTime[cmdValue.playerID])) then
						if cmdValue.spec then
							iconSize = 11
							glColor(glowColor[1], glowColor[2], glowColor[3], a * nicknameOpacityMultiplier)

							if cmdValue.cmdType == 'map_draw' then
								glScale(iconSize, 1, iconSize)
								glCallList(pencilDlist)
								local invIconSize = 1 / iconSize
								glScale(invIconSize, 1, invIconSize)
							else
								glScale(iconSize, 1, iconSize)
								glCallList(eraserDlist)
								local invIconSize = 1 / iconSize
								glScale(invIconSize, 1, invIconSize)
							end

							glPushMatrix()
							glBillboard()
							font:Begin()
							font:Print(cmdValue.nickname, 0, -28, 20, "cn")
							font:End()
							glPopMatrix()
						end
					end
				end

				glTranslate(-cmdValue.x, -cmdValue.y, -cmdValue.z)
				i = i + 1
			else
				i = i + 1
			end
		end
	end

	glPopMatrix()
	glColor(1, 1, 1, 1)
end

