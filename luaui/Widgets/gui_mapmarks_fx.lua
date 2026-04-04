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
local glBlending = gl.Blending
local glDepthTest = gl.DepthTest
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glColor = gl.Color
local glBillboard = gl.Billboard
local glTexCoord = gl.TexCoord
local glVertex = gl.Vertex
local glTexture = gl.Texture
local glBeginEnd = gl.BeginEnd

-- Localized math functions
local osClock = os.clock

-- this table is used to filter out previous map drawing nicknames
-- if user has drawn something new
local commands = {}
local mapDrawNicknameTime = {}
local mapEraseNicknameTime = {}

local ownPlayerID = Spring.GetLocalPlayerID()
local vsx,vsy = spGetViewGeometry()

local commandCount = 0
local font, chobbyInterface

-- Module-level batch arrays (reused each frame, no allocations)
local glowBatch = {}
local ringBatch = {}
local pencilBatch = {}
local eraserBatch = {}
local nickBatch = {}
local nickNames = {}

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

-- Precalculate scaled sizes and durations
for _, typeData in pairs(types) do
	typeData.sizeScaled = generalSize * typeData.size
	typeData.endSizeScaled = generalSize * typeData.endSize
	typeData.sizeDelta = typeData.endSizeScaled - typeData.sizeScaled
	typeData.totalDuration = typeData.duration * generalDuration
end

-- Pre-cache texture paths (avoid string concat each frame)
local glowTexture = imageDir .. 'glow.dds'
local ringTexture = imageDir .. 'ring.dds'
local pencilTexture = imageDir .. 'pencil.dds'
local eraserTexture = imageDir .. 'eraser.dds'

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawBatchedQuads(data, count)
	for j = 1, count, 8 do
		local x, y, z, s = data[j], data[j+1], data[j+2], data[j+3]
		glColor(data[j+4], data[j+5], data[j+6], data[j+7])
		glTexCoord(0, 0); glVertex(x - s, y, z - s)
		glTexCoord(0, 1); glVertex(x - s, y, z + s)
		glTexCoord(1, 1); glVertex(x + s, y, z + s)
		glTexCoord(1, 0); glVertex(x + s, y, z - s)
	end
end


local function AddEffect(cmdType, x, y, z, timestamp, unitID, playerID)
	if not playerID then
		playerID = false
	end
	local nickname, _, spec, teamID = spGetPlayerInfo(playerID, false)
	nickname = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or nickname

	local r, g, b = spGetTeamColor(teamID)

	commandCount = commandCount + 1
	commands[commandCount] = {
		cmdType		= cmdType,
		x			= x,
		y			= y,
		z			= z,
		osClock		= timestamp,
		playerID	= playerID,
		r			= r,
		g			= g,
		b			= b,
		spec		= spec,
		nickname	= nickname
	}
end


function widget:ViewResize()
	vsx,vsy = spGetViewGeometry()
	font = WG['fonts'].getFont(1, 1.5)
end


function widget:Initialize()
	widget:ViewResize()
end


function widget:Shutdown()
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
	commandCount = 0
end

function widget:DrawWorldPreUnit()
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then return end
	if WG.clearmapmarks and WG.clearmapmarks.continuous then return end
	if commandCount == 0 then return end

	local currentTime = osClock()

	-- Phase 1: Remove expired and obsolete commands
	local i = 1
	while i <= commandCount do
		local cmd = commands[i]
		if not cmd then
			commands[i] = commands[commandCount]
			commands[commandCount] = nil
			commandCount = commandCount - 1
		else
			local totalDuration = types[cmd.cmdType].totalDuration
			if currentTime - cmd.osClock > totalDuration
				or (cmd.cmdType == 'map_draw' and mapDrawNicknameTime[cmd.playerID] ~= nil
					and cmd.osClock < mapDrawNicknameTime[cmd.playerID]) then
				commands[i] = commands[commandCount]
				commands[commandCount] = nil
				commandCount = commandCount - 1
			else
				i = i + 1
			end
		end
	end

	if commandCount == 0 then return end

	-- Phase 2: Build batch data
	local glowN = 0
	local ringN = 0
	local pencilN = 0
	local eraserN = 0
	local nickN = 0

	for j = 1, commandCount do
		local cmd = commands[j]
		local typeData = types[cmd.cmdType]
		local totalDuration = typeData.totalDuration
		local durationProcess = (currentTime - cmd.osClock) / totalDuration
		local a = (1 - durationProcess) * generalOpacity
		local size = typeData.sizeScaled + (typeData.sizeDelta * durationProcess)

		local cr, cg, cb
		if cmd.spec then
			cr, cg, cb = 1, 1, 1
		else
			cr, cg, cb = cmd.r, cmd.g, cmd.b
		end

		-- Glow
		local glowAlpha = typeData.glowColor[4]
		if glowAlpha > 0 then
			local n = glowN
			local gs = size * 0.8
			glowBatch[n+1] = cmd.x; glowBatch[n+2] = cmd.y; glowBatch[n+3] = cmd.z
			glowBatch[n+4] = gs
			glowBatch[n+5] = cr; glowBatch[n+6] = cg; glowBatch[n+7] = cb
			glowBatch[n+8] = a * glowAlpha
			glowN = n + 8
		end

		-- Ring
		local ringAlpha = typeData.ringColor[4]
		if ringAlpha > 0 then
			local n = ringN
			local rs = ringStartSize + (size * ringScale) * durationProcess
			ringBatch[n+1] = cmd.x; ringBatch[n+2] = cmd.y; ringBatch[n+3] = cmd.z
			ringBatch[n+4] = rs
			ringBatch[n+5] = cr; ringBatch[n+6] = cg; ringBatch[n+7] = cb
			ringBatch[n+8] = a * ringAlpha
			ringN = n + 8
		end

		-- Icons & Nicknames (spectator drawers only)
		if cmd.spec and cmd.playerID and cmd.playerID ~= ownPlayerID then
			local cmdType = cmd.cmdType
			if cmdType == 'map_draw' or
				(cmdType == 'map_erase' and cmd.osClock >= (mapEraseNicknameTime[cmd.playerID] or 0)) then
				local iconAlpha = a * glowAlpha * nicknameOpacityMultiplier
				local is = 11
				if cmdType == 'map_draw' then
					local n = pencilN
					pencilBatch[n+1] = cmd.x; pencilBatch[n+2] = cmd.y; pencilBatch[n+3] = cmd.z
					pencilBatch[n+4] = is
					pencilBatch[n+5] = cr; pencilBatch[n+6] = cg; pencilBatch[n+7] = cb
					pencilBatch[n+8] = iconAlpha
					pencilN = n + 8
				else
					local n = eraserN
					eraserBatch[n+1] = cmd.x; eraserBatch[n+2] = cmd.y; eraserBatch[n+3] = cmd.z
					eraserBatch[n+4] = is
					eraserBatch[n+5] = cr; eraserBatch[n+6] = cg; eraserBatch[n+7] = cb
					eraserBatch[n+8] = iconAlpha
					eraserN = n + 8
				end
				nickN = nickN + 1
				local nn = (nickN - 1) * 4
				nickBatch[nn+1] = cmd.x; nickBatch[nn+2] = cmd.y; nickBatch[nn+3] = cmd.z
				nickBatch[nn+4] = iconAlpha
				nickNames[nickN] = cmd.nickname
			end
		end
	end

	-- Phase 3: Render batched (one texture bind + one draw call per type)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glDepthTest(false)

	if glowN > 0 then
		glTexture(glowTexture)
		glBeginEnd(GL.QUADS, DrawBatchedQuads, glowBatch, glowN)
		glTexture(false)
	end

	if ringN > 0 then
		glTexture(ringTexture)
		glBeginEnd(GL.QUADS, DrawBatchedQuads, ringBatch, ringN)
		glTexture(false)
	end

	if pencilN > 0 then
		glTexture(pencilTexture)
		glBeginEnd(GL.QUADS, DrawBatchedQuads, pencilBatch, pencilN)
		glTexture(false)
	end

	if eraserN > 0 then
		glTexture(eraserTexture)
		glBeginEnd(GL.QUADS, DrawBatchedQuads, eraserBatch, eraserN)
		glTexture(false)
	end

	if nickN > 0 then
		font:Begin()
		for j = 1, nickN do
			local nn = (j - 1) * 4
			glPushMatrix()
			glTranslate(nickBatch[nn+1], nickBatch[nn+2], nickBatch[nn+3])
			glColor(1, 1, 1, nickBatch[nn+4])
			glBillboard()
			font:Print(nickNames[j], 0, -28, 20, "cn")
			glPopMatrix()
		end
		font:End()
	end

	glColor(1, 1, 1, 1)
end

