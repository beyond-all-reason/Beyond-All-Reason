local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Start Boxes",
		desc = "Displays Start Boxes and Start Points",
		author = "trepan, jK, Beherith, SethDGamre",
		date = "2007-2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		depends = {'gl4'}
	}
end

local Spring = Spring
local gl = gl
local math = math
local mathFloor = math.floor
local mathRandom = math.random
local mathAbs = math.abs

local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spEcho = Spring.Echo
local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamList = Spring.GetTeamList
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetGroundHeight = Spring.GetGroundHeight
local glDrawGroundCircle = gl.DrawGroundCircle

local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SHADER_STORAGE_BUFFER = GL.SHADER_STORAGE_BUFFER
local GL_TRIANGLES = GL.TRIANGLES

local UPDATE_RATE = 30

local getCurrentMiniMapRotationOption = VFS.Include("luaui/Include/minimap_utils.lua").getCurrentMiniMapRotationOption
local ROTATION = VFS.Include("luaui/Include/minimap_utils.lua").ROTATION

if Game.startPosType ~= 2 then
	return false
end

local draftMode = Spring.GetModOptions().draft_mode
local allowEnemyAIPlacement = Spring.GetModOptions().allow_enemy_ai_spawn_placement

local tooCloseToSpawn

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = 0.5 + (vsx * vsy / 5700000)
local fontfileSize = 50
local fontfileOutlineSize = 8
local fontfileOutlineStrength = 1.65
local fontfileOutlineStrength2 = 10
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
local shadowFont = gl.LoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.5)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength2)

local useThickLeterring = false
local fontSize = 18
local fontShadow = true        -- only shows if font has a white outline
local shadowOpacity = 0.35

local infotextFontsize = 13

local commanderNameList = {}
local aiPlacementStatus = {}
local usedFontSize = fontSize
local widgetScale = (1 + (vsx * vsy / 5500000))
local startPosRatio = 0.0001
local startPosScale
if getCurrentMiniMapRotationOption() == ROTATION.DEG_90 or getCurrentMiniMapRotationOption() == ROTATION.DEG_270 then
	startPosScale = (vsx*startPosRatio) / select(4, Spring.GetMiniMapGeometry())
else
	startPosScale = (vsx*startPosRatio) / select(3, Spring.GetMiniMapGeometry())
end

local isSpec = spGetSpectatingState() or Spring.IsReplay()
local myTeamID = spGetMyTeamID()

local placeVoiceNotifTimer = false
local playedChooseStartLoc = false

local amPlaced = false

local gaiaTeamID

local startTimer = Spring.GetTimer()
local lastRot = -1 --TODO: switch this to use MiniMapRotationChanged Callin when it is added to Engine

local infotextList

local GetTeamColor = Spring.GetTeamColor

local ColorIsDark = Spring.Utilities.Color.ColorIsDark

local glTranslate = gl.Translate
local glCallList = gl.CallList
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glTexCoord = gl.TexCoord
local GL_POLYGON = GL.POLYGON
local GL_QUADS = GL.QUADS

local hasStartbox = false

-- Cache for start unit textures
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

local coopStartPoints = {}
local aiCurrentlyBeingPlaced = nil
local aiPlacedPositions = {}
local aiPredictedPositions = {}

local draggingTeamID = nil
local dragOffsetX = 0
local dragOffsetZ = 0

local myAllyTeamID = Spring.GetMyAllyTeamID()
local gameFrame = 0

local CONE_CLICK_RADIUS = 75
local LEFT_BUTTON = 1
local RIGHT_BUTTON = 3

VFS.Include("common/lib_startpoint_guesser.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local aiNameI18NTable = {name = ""}
local aiLocationI18NTable = {playerName = "", aiName = ""}
local aiNameCache = {}
local aiNameLockedCache = {}

local function getAIName(teamID, includeLock)
	if includeLock and aiNameLockedCache[teamID] then
		local hasPlacement = aiPlacementStatus[teamID]
		if hasPlacement == nil then
			local startX, _, startZ = spGetTeamStartPosition(teamID)
			hasPlacement = (startX and startZ and startX > 0 and startZ > 0) or spGetTeamRulesParam(teamID, "aiManualPlacement")
		end
	end

	local baseName = aiNameCache[teamID]
	if not baseName then
		local _, playerID, _, isAI = spGetTeamInfo(teamID, false)
		if isAI then
			local _, _, _, aiName = Spring.GetAIInfo(teamID)
			local niceName = Spring.GetGameRulesParam('ainame_' .. teamID)
			if niceName then
				aiName = niceName
			end
			aiNameI18NTable.name = aiName
			baseName = Spring.I18N('ui.playersList.aiName', aiNameI18NTable)
		else
			local name = spGetPlayerInfo(playerID, false)
			baseName = WG.playernames and WG.playernames.getPlayername(playerID) or name
		end
		aiNameCache[teamID] = baseName
	end

	if includeLock then
		local hasPlacement = aiPlacementStatus[teamID]
		if hasPlacement == nil then
			local startX, _, startZ = spGetTeamStartPosition(teamID)
			hasPlacement = (startX and startZ and startX > 0 and startZ > 0) or spGetTeamRulesParam(teamID, "aiManualPlacement")
		end
		if hasPlacement then
			return baseName .. "\n🔒"
		end
	end

	return baseName
end

local teamColorComponents = {}
local cachedTeamList = {}

local function updateTeamList()
	cachedTeamList = spGetTeamList()
end

local function assignTeamColors()
	updateTeamList()
	local changed = false
	for _, teamID in ipairs(cachedTeamList) do
		local r, g, b = GetTeamColor(teamID)
		local cached = teamColorComponents[teamID]
		if not cached or cached[1] ~= r or cached[2] ~= g or cached[3] ~= b then
			if not cached then
				teamColorComponents[teamID] = {r, g, b}
			else
				cached[1], cached[2], cached[3] = r, g, b
			end
			changed = true
		end
	end
	return changed
end

function widget:PlayerChanged(playerID)
	updateTeamList()
	isSpec = spGetSpectatingState()
	myTeamID = spGetMyTeamID()
end

local function createCommanderNameList(name, teamID)
	commanderNameList[teamID] = {}
	commanderNameList[teamID]['name'] = name
	commanderNameList[teamID]['list'] = gl.CreateList(function()
		local x, y = 0, 0
		local r, g, b = GetTeamColor(teamID)
		local outlineColor = { 0, 0, 0, 1 }
		if ColorIsDark(r, g, b) then
			outlineColor = { 1, 1, 1, 1 }
		end
		if useThickLeterring then
			if outlineColor[1] == 1 and fontShadow then
				glTranslate(0, -(usedFontSize / 44), 0)
				shadowFont:Begin()
				shadowFont:SetTextColor({ 0, 0, 0, shadowOpacity })
				shadowFont:SetOutlineColor({ 0, 0, 0, shadowOpacity })
				shadowFont:Print(name, x, y, usedFontSize, "con")
				shadowFont:End()
				glTranslate(0, (usedFontSize / 44), 0)
			end
			font2:Begin()
			font2:SetTextColor(outlineColor)
			font2:SetOutlineColor(outlineColor)

			font2:Print(name, x - (usedFontSize / 38), y - (usedFontSize / 33), usedFontSize, "con")
			font2:Print(name, x + (usedFontSize / 38), y - (usedFontSize / 33), usedFontSize, "con")
			font2:End()
		end
		font2:Begin()
		font2:SetTextColor({r, g, b})
		font2:SetOutlineColor(outlineColor)
		font2:Print(name, x, y, usedFontSize, "con")
		font2:End()
	end)
end

local function drawName(x, y, name, teamID)
	if commanderNameList[teamID] == nil or commanderNameList[teamID]['name'] ~= name then
		if commanderNameList[teamID] ~= nil then
			gl.DeleteList(commanderNameList[teamID]['list'])
		end
		createCommanderNameList(name, teamID)
	end
	glPushMatrix()
	glTranslate(mathFloor(x), mathFloor(y), 0)
	glCallList(commanderNameList[teamID]['list'])
	glPopMatrix()
end

local function createInfotextList()
	local infotext = Spring.I18N('ui.startSpot.anywhere')
	local infotextBoxes = Spring.I18N('ui.startSpot.startbox')

	if infotextList then
		gl.DeleteList(infotextList)
	end
	infotextList = gl.CreateList(function()
		font:Begin()
		font:SetTextColor(0.9, 0.9, 0.9, 1)
		if draftMode == nil or draftMode == "disabled" then -- otherwise draft mod will play it instead
			font:Print(hasStartbox and infotextBoxes or infotext, 0, 0, infotextFontsize * widgetScale, "cno")
		end
		font:End()
	end)
end


local posCache = {}

local function getEffectiveStartPosition(teamID)
	if draggingTeamID == teamID then
		local mouseX, mouseY = Spring.GetMouseState()
		local traceType, pos = Spring.TraceScreenRay(mouseX, mouseY, true)
		if traceType == "ground" then
			local x = pos[1] + dragOffsetX
			local z = pos[3] + dragOffsetZ
			local y = pos[2]
			return x, y, z
		end
	end

	local posCacheTeam = posCache[teamID]
	if posCacheTeam and posCacheTeam[4] then
		return posCacheTeam[1], posCacheTeam[2], posCacheTeam[3]
	end

	local playerID = select(2, spGetTeamInfo(teamID, false))
	local x, y, z = spGetTeamStartPosition(teamID)

	local coopStartPoint = coopStartPoints[playerID]
	if coopStartPoint then
		x, y, z = coopStartPoint[1], coopStartPoint[2], coopStartPoint[3]
	end

	if aiPlacedPositions[teamID] then
		local aiPlacedPos = aiPlacedPositions[teamID]
		x, z = aiPlacedPos.x, aiPlacedPos.z
		y = spGetGroundHeight(x, z)
	elseif aiPredictedPositions[teamID] then
		local aiPredictedPos = aiPredictedPositions[teamID]
		x, z = aiPredictedPos.x, aiPredictedPos.z
		y = spGetGroundHeight(x, z)
	end

	if posCacheTeam then
		posCacheTeam[1], posCacheTeam[2], posCacheTeam[3], posCacheTeam[4] = x, y, z, true
	else
		posCache[teamID] = {x, y, z, true}
	end
	return x, y, z
end

local function clearPosCache()
	for teamID, entry in pairs(posCache) do
		if entry then
			entry[4] = false
		end
	end
end

local function invalidatePosCacheEntry(teamID)
	local entry = posCache[teamID]
	if entry then
		entry[4] = false
	end
end

local function shouldRenderTeam(teamID, excludeMyTeam)
	if teamID == gaiaTeamID or (excludeMyTeam and teamID == myTeamID) then
		return false
	end

	local _, playerID, _, isAI, _, teamAllyTeamID = spGetTeamInfo(teamID, false)
	local _, _, spec = spGetPlayerInfo(playerID, false)

	local x, y, z = getEffectiveStartPosition(teamID)

	local isVisible = (not spec or isAI) and teamID ~= gaiaTeamID and
		(not isAI or teamAllyTeamID == myAllyTeamID or isSpec or allowEnemyAIPlacement)

	local isValidPosition = x ~= nil and x > 0 and z > 0 and y > -500

	return isVisible and isValidPosition, x, y, z, isAI
end

local allSpawnPositions = {}
local function notifySpawnPositionsChanged()
	if not WG["quick_start_updateSpawnPositions"] then
		return
	end

	for k in pairs(allSpawnPositions) do allSpawnPositions[k] = nil end
	for _, teamID in ipairs(cachedTeamList) do
		local shouldRender, x, y, z = shouldRenderTeam(teamID, false)
		if shouldRender then
			local entry = allSpawnPositions[teamID]
			if not entry then
				allSpawnPositions[teamID] = {x = x, z = z}
			else
				entry.x, entry.z = x, z
			end
		end
	end
	WG["quick_start_updateSpawnPositions"](allSpawnPositions)
end

function widget:LanguageChanged()
	createInfotextList()
end

local function CoopStartPoint(playerID, x, y, z)
	coopStartPoints[playerID] = {x, y, z}
	notifySpawnPositionsChanged()
end

---------------------------------- StartPolygons ----------------------------------
-- Note: this is now updated to support arbitrary start polygons via GL.SHADER_STORAGE_BUFFER

-- The format of the buffer is the following:
-- Triplets of :teamID, triangleID, x, z

-- spEcho(spGetTeamInfo(spGetMyTeamID()))

-- TODO:
-- [ ] Handle overlapping of boxes and myAllyTeamID
-- [X] Handle Minimap drawing too
-- [X] handle flipped minimaps
-- [ ] Pass in my team too
-- [ ] Handle Scavengers in scavenger color
-- [ ] Handle Raptors in raptor color

local scavengerStartBoxTexture = "LuaUI/Images/scav-tileable_v002_small.tga"

local raptorStartBoxTexture = "LuaUI/Images/rapt-tileable_v002_small.tga"

local scavengerAIAllyTeamID = Spring.Utilities.GetScavAllyTeamID()
local raptorsAIAllyTeamID = Spring.Utilities.GetRaptorAllyTeamID()

---- Config stuff ------------------
local autoReload = false -- refresh shader code every second (disable in production!)

local StartPolygons = {} -- list of points in clockwise order

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance

-- spEcho('Spring.GetGroundExtremes', minY, maxY, waterlevel)

local shaderSourceCache = {
		vssrcpath = "LuaUI/Shaders/map_startpolygon_gl4.vert.glsl",
		fssrcpath = "LuaUI/Shaders/map_startpolygon_gl4.frag.glsl",
		uniformInt = {
			mapDepths = 0,
			myAllyTeamID = -1,
			isMiniMap = 0,
			roationMiniMap = 0,
			mapNormals = 1,
			heightMapTex = 2,
			scavTexture = 3,
			raptorTexture = 4,
		},
		uniformFloat = {
			pingData = {0,0,0,-10000}, -- x,y,z, time
			isMiniMap = 0,
			pipVisibleArea = {0, 1, 0, 1}, -- left, right, bottom, top in normalized [0,1] coords for PIP minimap
		},
		shaderName = "Start Polygons GL4",
		shaderConfig = {
			ALPHA = 0.5,
			NUM_POLYGONS = 0,
			NUM_POINTS = 0,
			MAX_STEEPNESS = math.cos(math.rad(54)),
			SCAV_ALLYTEAM_ID = scavengerAIAllyTeamID, -- these neatly become undefined if not present
			RAPTOR_ALLYTEAM_ID = raptorsAIAllyTeamID,
		},
		silent = (not autoReload),
	}

local fullScreenRectVAO
local startPolygonShader
local startPolygonBuffer = nil -- GL.SHADER_STORAGE_BUFFER for polygon

local coneShaderSourceCache = {
	vssrcpath = "LuaUI/Shaders/map_startcone_gl4.vert.glsl",
	fssrcpath = "LuaUI/Shaders/map_startcone_gl4.frag.glsl",
	uniformInt = {
		mapDepths = 0,
		rotationMiniMap = 0,
	},
	uniformFloat = {
		isMiniMap = 0,
		pipVisibleArea = {0, 1, 0, 1}, -- left, right, bottom, top in normalized [0,1] coords for PIP minimap
	},
	shaderName = "Start Cones GL4",
	shaderConfig = {
		ALPHA = 0.5,
	},
	silent = (not autoReload),
}

local startConeVBOTable = nil
local startConeShader = nil

local function DrawStartPolygons(inminimap)

	local _, advMapShading = Spring.HaveAdvShading()

	if advMapShading then
		gl.Texture(0, "$map_gbuffer_zvaltex")
	else
		if WG['screencopymanager'] and WG['screencopymanager'].GetDepthCopy() then
			gl.Texture(0, WG['screencopymanager'].GetDepthCopy())
		else
			spEcho("Start Polygons: Adv map shading not available, and no depth copy available")
			return
		end
	end

	gl.Texture(1, "$normals")
	gl.Texture(2, "$heightmap")-- Texture file
	gl.Texture(3, scavengerStartBoxTexture)
	gl.Texture(4, raptorStartBoxTexture)

	startPolygonBuffer:BindBufferRange(4)

	gl.Culling(true)
	gl.DepthTest(false)
	gl.DepthMask(false)

	startPolygonShader:Activate()

	startPolygonShader:SetUniform("noRushTimer", noRushTime)
	startPolygonShader:SetUniformInt("isMiniMap", inminimap and 1 or 0)

	startPolygonShader:SetUniformInt("rotationMiniMap", getCurrentMiniMapRotationOption() or ROTATION.DEG_0)
	startPolygonShader:SetUniformInt("myAllyTeamID", myAllyTeamID or -1)

	-- Pass PIP visible area if drawing in PIP minimap
	if inminimap and WG['minimap'] and WG['minimap'].isDrawingInPip and WG['minimap'].getNormalizedVisibleArea then
		local left, right, bottom, top = WG['minimap'].getNormalizedVisibleArea()
		startPolygonShader:SetUniform("pipVisibleArea", left, right, bottom, top)
	else
		startPolygonShader:SetUniform("pipVisibleArea", 0, 1, 0, 1)
	end

	fullScreenRectVAO:DrawArrays(GL_TRIANGLES)
	startPolygonShader:Deactivate()
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)
	gl.Texture(4, false)
	gl.Culling(false)
	gl.DepthTest(false)
end

local function DrawStartCones(inminimap)
	startConeShader:Activate()
	startConeShader:SetUniform("isMinimap", inminimap and 1 or 0)
	startConeShader:SetUniformInt("rotationMiniMap", getCurrentMiniMapRotationOption() or ROTATION.DEG_0)

	-- Pass PIP visible area if drawing in PIP minimap
	if inminimap and WG['minimap'] and WG['minimap'].isDrawingInPip and WG['minimap'].getNormalizedVisibleArea then
		local left, right, bottom, top = WG['minimap'].getNormalizedVisibleArea()
		startConeShader:SetUniform("pipVisibleArea", left, right, bottom, top)
	else
		startConeShader:SetUniform("pipVisibleArea", 0, 1, 0, 1)
	end

	startConeShader:SetUniformFloat("startPosScale", startPosScale)

	startConeVBOTable:draw()
	startConeShader:Deactivate()
end

local cacheTable = {}
local circlesToDraw = {}
local function getCircleEntry(index)
	if not circlesToDraw[index] then
		circlesToDraw[index] = {0, 0, 0}
	end
	return circlesToDraw[index]
end

local teamsToRender = {}
local teamsToRenderCount = 0

local function updateTeamsToRender()
	teamsToRenderCount = 0
	for _, teamID in ipairs(cachedTeamList) do
		local shouldRender, x, y, z, isAI = shouldRenderTeam(teamID, false)
		if shouldRender then
			teamsToRenderCount = teamsToRenderCount + 1
			local entry = teamsToRender[teamsToRenderCount]
			if not entry then
				entry = {}
				teamsToRender[teamsToRenderCount] = entry
			end
			entry.teamID = teamID
			entry.x = x
			entry.y = y
			entry.z = z
			entry.isAI = isAI
		end
	end
end

local function getStartUnitTexture(teamID)
	-- Don't cache - need to update when player changes faction
	local startUnitDefID = spGetTeamRulesParam(teamID, 'startUnit')
	if startUnitDefID then
		local uDef = UnitDefs[startUnitDefID]
		if uDef then
			-- Check if it's a "random" faction (dummy unit)
			if uDef.name == "yourmomdummy" or string.sub(uDef.name, 1, 3) == "dum" then
				return 'unitpics/other/dice.dds'
			end
			return 'unitpics/' .. uDef.name .. '.dds'
		end
	end
	-- Fallback: dice for unknown/random
	return 'unitpics/other/dice.dds'
end

local function DrawStartUnitIcons(sx, sz, inPip)
	-- Ensure teams data is populated (DrawInMiniMap may be called before DrawWorld)
	if not teamsToRenderCount or teamsToRenderCount == 0 then
		clearPosCache()
		updateTeamsToRender()
	end

	local rotation = getCurrentMiniMapRotationOption() or ROTATION.DEG_0

	-- Icon size in pixels (same for both engine minimap and PIP)
	-- PIP sets up GL transforms so pixel coords work the same way
	local iconSize = math.max(sx, sz) * 0.06

	-- Precompute scale factors
	local sxOverMapX = sx / mapSizeX
	local szOverMapZ = sz / mapSizeZ
	local sxOverMapZ = sx / mapSizeZ
	local szOverMapX = sz / mapSizeX

	for i = 1, (teamsToRenderCount or 0) do
		local entry = teamsToRender[i]
		local teamID = entry.teamID
		local worldX, worldZ = entry.x, entry.z

		-- Get the texture for this team's start unit
		local texPath = getStartUnitTexture(teamID)
		if texPath then
			-- Apply minimap rotation and convert to pixel coords
			-- Match the coordinate system used by other widgets (e.g., unit_share_tracker)
			local drawX, drawY
			if rotation == ROTATION.DEG_0 then
				drawX = worldX * sxOverMapX
				drawY = sz - worldZ * szOverMapZ
			elseif rotation == ROTATION.DEG_90 then
				drawX = worldZ * sxOverMapZ
				drawY = worldX * szOverMapX
			elseif rotation == ROTATION.DEG_180 then
				drawX = sx - worldX * sxOverMapX
				drawY = worldZ * szOverMapZ
			elseif rotation == ROTATION.DEG_270 then
				drawX = sx - worldZ * sxOverMapZ
				drawY = sz - worldX * szOverMapX
			else
				drawX = worldX * sxOverMapX
				drawY = sz - worldZ * szOverMapZ
			end

			-- Snap to nearest pixel to eliminate sub-pixel jitter
			drawX = math.floor(drawX + 0.5)
			drawY = math.floor(drawY + 0.5)

			-- Draw team-colored background with chamfered corners
			local r, g, b = GetTeamColor(teamID)
			glTexture(false)
			local halfSize = iconSize * 0.535
			-- Chamfer size: 1.5-3 pixels depending on resolution (scale with minimap size)
			local chamfer = math.max(1.5, math.min(3, math.max(sx, sz) * 0.008))

			-- Draw octagon (rectangle with chamfered corners)
			local x1, y1 = drawX - halfSize, drawY - halfSize
			local x2, y2 = drawX + halfSize, drawY + halfSize

			-- Draw dark border octagon (slightly larger)
			local borderSize = 1
			local bx1, by1 = x1 - borderSize, y1 - borderSize
			local bx2, by2 = x2 + borderSize, y2 + borderSize
			local borderChamfer = chamfer + borderSize * 0.7
			glColor(0, 0, 0, 0.25)
			glBeginEnd(GL_POLYGON, function()
				glVertex(bx1 + borderChamfer, by1)
				glVertex(bx2 - borderChamfer, by1)
				glVertex(bx2, by1 + borderChamfer)
				glVertex(bx2, by2 - borderChamfer)
				glVertex(bx2 - borderChamfer, by2)
				glVertex(bx1 + borderChamfer, by2)
				glVertex(bx1, by2 - borderChamfer)
				glVertex(bx1, by1 + borderChamfer)
			end)

			-- Draw team-colored octagon
			glColor(r, g, b, 0.7)
			glBeginEnd(GL_POLYGON, function()
				-- Bottom edge (left to right)
				glVertex(x1 + chamfer, y1)
				glVertex(x2 - chamfer, y1)
				-- Bottom-right corner
				glVertex(x2, y1 + chamfer)
				-- Right edge
				glVertex(x2, y2 - chamfer)
				-- Top-right corner
				glVertex(x2 - chamfer, y2)
				-- Top edge (right to left)
				glVertex(x1 + chamfer, y2)
				-- Top-left corner
				glVertex(x1, y2 - chamfer)
				-- Left edge
				glVertex(x1, y1 + chamfer)
				-- Bottom-left corner closes the loop
			end)

			-- Draw the unit icon with chamfered corners and slight zoom
			glColor(1, 1, 1, 1)
			glTexture(texPath)
			local iconHalf = iconSize * 0.45
			local ix1, iy1 = drawX - iconHalf, drawY - iconHalf
			local ix2, iy2 = drawX + iconHalf, drawY + iconHalf
			local texZoom = 0.035  -- 7% zoom means 3.5% border on each side
			local iconChamfer = chamfer * 0.7  -- Slightly smaller chamfer for inner icon

			-- Calculate chamfer in texture space
			local iconSize2 = iconHalf * 2
			local texChamfer = (iconChamfer / iconSize2) * (1 - 2 * texZoom)

			-- Draw octagon with textured chamfered corners (flip Y by swapping texcoord Y)
			glBeginEnd(GL_POLYGON, function()
				-- Bottom edge (left to right) - tex Y flipped: bottom = 1-texZoom
				glTexCoord(texZoom + texChamfer, 1 - texZoom)
				glVertex(ix1 + iconChamfer, iy1)
				glTexCoord(1 - texZoom - texChamfer, 1 - texZoom)
				glVertex(ix2 - iconChamfer, iy1)
				-- Bottom-right corner
				glTexCoord(1 - texZoom, 1 - texZoom - texChamfer)
				glVertex(ix2, iy1 + iconChamfer)
				-- Right edge
				glTexCoord(1 - texZoom, texZoom + texChamfer)
				glVertex(ix2, iy2 - iconChamfer)
				-- Top-right corner - tex Y flipped: top = texZoom
				glTexCoord(1 - texZoom - texChamfer, texZoom)
				glVertex(ix2 - iconChamfer, iy2)
				-- Top edge (right to left)
				glTexCoord(texZoom + texChamfer, texZoom)
				glVertex(ix1 + iconChamfer, iy2)
				-- Top-left corner
				glTexCoord(texZoom, texZoom + texChamfer)
				glVertex(ix1, iy2 - iconChamfer)
				-- Left edge
				glTexCoord(texZoom, 1 - texZoom - texChamfer)
				glVertex(ix1, iy1 + iconChamfer)
			end)
		end
	end

	glTexture(false)
	glColor(1, 1, 1, 1)
end


local function InitStartPolygons()
	local gaiaAllyTeamID
	if Spring.GetGaiaTeamID() then
		gaiaAllyTeamID = select(6, spGetTeamInfo(Spring.GetGaiaTeamID() , false))
	end
	for i, teamID in ipairs(Spring.GetAllyTeamList()) do
		if teamID ~= gaiaAllyTeamID then
			--and teamID ~= scavengerAIAllyTeamID and teamID ~= raptorsAIAllyTeamID then
			local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(teamID)
			--spEcho("Allyteam",teamID,"startbox",xn, zn, xp, zp)
			StartPolygons[teamID] = {{xn, zn}, {xp, zn}, {xp, zp}, {xn, zp}}
		end
	end

	if autoReload and false then
		-- MANUAL OVERRIDE FOR DEBUGGING
		-- lets add a bunch of silly StartPolygons:
		StartPolygons = {}
		for i = 2,8 do
			local x0 = mathRandom(0, Game.mapSizeX)
			local y0 = mathRandom(0, Game.mapSizeZ)
			local polygon = {{x0, y0}}

			for j = 2, math.ceil(mathRandom() * 10) do
				local x1 = mathRandom(0, Game.mapSizeX / 5)
				local y1 = mathRandom(0, Game.mapSizeZ / 5)
				polygon[#polygon+1] = {x0+x1, y0+y1}
			end
			StartPolygons[#StartPolygons+1] = polygon
		end
	end

	--Case we start with only one team(no enemies)
	--The shader doesn't like that so we have to let it think there are more then one
	if(#StartPolygons == 0) then
		StartPolygons[#StartPolygons+1] = StartPolygons[#StartPolygons]
	end

	shaderSourceCache.shaderConfig.NUM_BOXES = #StartPolygons

	local minY, maxY = Spring.GetGroundExtremes()
	local waterlevel = (Spring.GetModOption and Spring.GetModOptions().map_waterlevel) or 0
	if waterlevel > 0 then
		minY = minY - waterlevel
		maxY = maxY - waterlevel
	end
	shaderSourceCache.shaderConfig.MINY = minY - 1024
	shaderSourceCache.shaderConfig.MAXY = maxY + 1024

	local numvertices = 0
	local bufferdata = {}
	local numPolygons = 0
	for teamID, polygon in pairs(StartPolygons) do
		numPolygons = numPolygons + 1
		local numPoints = #polygon
		local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(teamID)
		--spEcho("teamID", teamID, "at " ,xn, zn, xp, zp)
		for vertexID, vertex in ipairs(polygon) do
			local x, z = vertex[1], vertex[2]
			bufferdata[#bufferdata+1] = teamID
			bufferdata[#bufferdata+1] = numPoints
			bufferdata[#bufferdata+1] = x
			bufferdata[#bufferdata+1] = z
			numvertices = numvertices + 1
		end
	end

	-- SHADER_STORAGE_BUFFER MUST HAVE 64 byte aligned data
	if numvertices % 4 ~= 0 then
		for i=1, ((4 - (numvertices % 4)) * 4) do bufferdata[#bufferdata+1] = -1 end
		numvertices = numvertices + (4 - numvertices % 4)
	end

	startPolygonBuffer = gl.GetVBO(GL_SHADER_STORAGE_BUFFER, false) -- not updated a lot
	startPolygonBuffer:Define(numvertices, {{id = 0, name = 'starttriangles', size = 4}})
	startPolygonBuffer:Upload(bufferdata)--, -1, 0, 0, numvertices-1)

	shaderSourceCache.shaderConfig.NUM_POLYGONS = numPolygons
	shaderSourceCache.shaderConfig.NUM_POINTS = numvertices
	startPolygonShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or startPolygonShader

	if not startPolygonShader then
		spEcho("Error: startPolygonShader shader not initialized")
		widgetHandler:RemoveWidget()
		return
	end
	fullScreenRectVAO = InstanceVBOTable.MakeTexRectVAO()

	local coneVBO, numConeVertices = InstanceVBOTable.makeConeVBO(32, 100, 25)
	startConeVBOTable = InstanceVBOTable.makeInstanceVBOTable(
		{
			-- Cause 0-1-2 contain primitive per-vertex data
			{id = 3, name = 'worldposradius', size = 4}, -- xpos, ypos, zpos, radius
			{id = 4, name = 'teamColor', size = 4}, -- rgba
		},
		64, -- maxelements
		"StartConeVBO" -- name
	)
	startConeVBOTable.numVertices = numConeVertices
	if startConeVBOTable == nil then
		goodbye("Failed to create StartConeVBO")
		widgetHandler:RemoveWidget()
		return
	end

	startConeVBOTable.vertexVBO = coneVBO

	startConeVBOTable.VAO = InstanceVBOTable.makeVAOandAttach(startConeVBOTable.vertexVBO,startConeVBOTable.instanceVBO)

	startConeShader = LuaShader.CheckShaderUpdates(coneShaderSourceCache) or startConeShader

	if not startConeShader then
		spEcho("Error: startConeShader shader not initialized")
		widgetHandler:RemoveWidget()
		return
	end

end

--------------------------------------------------------------------------------

function widget:Initialize()
	if spGetGameFrame() > 1 then
		widgetHandler:RemoveWidget()
		return
	end

	tooCloseToSpawn = Spring.GetGameRulesParam("tooCloseToSpawn") or 350

	widgetHandler:RegisterGlobal('GadgetCoopStartPoint', CoopStartPoint)

	WG['map_startbox'] = {}
	WG['map_startbox'].GetEffectiveStartPosition = getEffectiveStartPosition

	updateTeamList()
	assignTeamColors()

	gaiaTeamID = Spring.GetGaiaTeamID()

	for _, teamID in ipairs(cachedTeamList) do
		if teamID ~= gaiaTeamID then
			local _, _, _, isAI, _, _ = spGetTeamInfo(teamID, false)
			if isAI then
				local startX, _, startZ = spGetTeamStartPosition(teamID)
				local aiManualPlacement = spGetTeamRulesParam(teamID, "aiManualPlacement")

				if (startX and startZ and startX > 0 and startZ > 0) or aiManualPlacement then
					if aiManualPlacement then
						local mx, mz = string.match(aiManualPlacement, "([%d%.]+),([%d%.]+)")
						if mx and mz then
							startX, startZ = tonumber(mx), tonumber(mz)
						end
					end

					if startX and startZ then
						aiPlacedPositions[teamID] = {x = startX, z = startZ}
						aiPlacementStatus[teamID] = true
					end
				else
					aiPlacementStatus[teamID] = false
				end
			end
		end
	end

	createInfotextList()

	InitStartPolygons()
end

local function removeTeamLists()
	for _, teamID in ipairs(cachedTeamList) do
		if commanderNameList[teamID] ~= nil then
			gl.DeleteList(commanderNameList[teamID].list)
		end
	end
	commanderNameList = {}
end

local function removeLists()
	gl.DeleteList(infotextList)
	removeTeamLists()
end

function widget:Shutdown()
	removeLists()
	gl.DeleteFont(font)
	gl.DeleteFont(font2)
	gl.DeleteFont(shadowFont)
	widgetHandler:DeregisterGlobal('GadgetCoopStartPoint')
	WG['map_startbox'] = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawWorldPreUnit()
	if autoReload then
		startPolygonShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or startPolygonShader
		startConeShader = LuaShader.CheckShaderUpdates(coneShaderSourceCache) or startConeShader
	end
	DrawStartPolygons(false)
end

local cacheTable = {}
local circlesToDraw = {}
local function getCircleEntry(index)
	if not circlesToDraw[index] then
		circlesToDraw[index] = {0, 0, 0}
	end
	return circlesToDraw[index]
end

function widget:DrawWorld()
	clearPosCache()
	updateTeamsToRender() -- Calculate visibility once per frame

	gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)
	local alpha = 0.5 + mathAbs(((time * 3) % 1) - 0.5)

	InstanceVBOTable.clearInstanceTable(startConeVBOTable)

	local cCount = 0

	for i = 1, teamsToRenderCount do
		local entry = teamsToRender[i]
		local teamID = entry.teamID
		local x, y, z = entry.x, entry.y, entry.z
		local isAI = entry.isAI

		local r, g, b = GetTeamColor(teamID)

		cacheTable[1], cacheTable[2], cacheTable[3], cacheTable[4] = x, y, z, 1
		cacheTable[5], cacheTable[6], cacheTable[7], cacheTable[8] = r, g, b, alpha
		pushElementInstance(startConeVBOTable,
			cacheTable,
			nil, nil, true)
		if teamID == myTeamID then
			amPlaced = true
		end

		if teamID ~= myTeamID and (not isAI or aiPlacedPositions[teamID]) then
			cCount = cCount + 1
			local circleEntry = getCircleEntry(cCount)
			circleEntry[1], circleEntry[2], circleEntry[3] = x, y, z
		end
	end

	InstanceVBOTable.uploadAllElements(startConeVBOTable)

	--DrawStartCones(false)

	if cCount > 0 then
		gl.Color(1.0, 0.0, 0.0, 0.3)
		for i = 1, cCount do
			local p = circlesToDraw[i]
			glDrawGroundCircle(p[1], p[2], p[3], tooCloseToSpawn, 32)
		end
	end
end

function widget:DrawScreenEffects()
	-- show the names over the team start positions
	for i = 1, teamsToRenderCount do
		local entry = teamsToRender[i]
		local teamID = entry.teamID
		local x, y, z = entry.x, entry.y, entry.z
		local isAI = entry.isAI

		local _, playerID = spGetTeamInfo(teamID, false)
		local name = spGetPlayerInfo(playerID, false)

		if isAI then
			name = getAIName(teamID, true)
		else
			name = WG.playernames and WG.playernames.getPlayername(playerID) or name
		end

		if name then
			local sx, sy, sz = Spring.WorldToScreenCoords(x, y + 120, z)
			if sz < 1 then
				drawName(sx, sy, name, teamID)
			end
		end
	end
end

function widget:DrawScreen()
	if not isSpec then
		gl.PushMatrix()
		gl.Translate(vsx / 2, vsy / 6.2, 0)
		gl.Scale(1 * widgetScale, 1 * widgetScale, 1)
		gl.CallList(infotextList)
		gl.PopMatrix()
	end
end

function widget:DrawInMiniMap(sx, sz)
	if gameFrame > 1 then
		widgetHandler:RemoveWidget()
		return
	end

	-- Check if we're being called from PIP minimap
	local inPip = WG['minimap'] and WG['minimap'].isDrawingInPip

	DrawStartPolygons(true)
	DrawStartUnitIcons(sx, sz, inPip)

end

function widget:ViewResize(x, y)
	vsx, vsy = x, y
	widgetScale = (0.75 + (vsx * vsy / 7500000))

	local currRot = getCurrentMiniMapRotationOption()
	if currRot == ROTATION.DEG_90 or currRot == ROTATION.DEG_270 then
		startPosScale = (vsx*startPosRatio) / select(4, Spring.GetMiniMapGeometry())
	else
		startPosScale = (vsx*startPosRatio) / select(3, Spring.GetMiniMapGeometry())
	end
	removeTeamLists()
	usedFontSize = fontSize * widgetScale
	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		gl.DeleteFont(shadowFont)
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
		font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength2)
		shadowFont = gl.LoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.6)
		createInfotextList()
	end
end

-- reset needed when waterlevel has changed by gadget (modoption)

local sec = 0
local updateCounter = 0
local lastKnownPlacements = {}
local currentPlacements = {}
local startPointTable = {}
function widget:Update(delta)
	myAllyTeamID = Spring.GetMyAllyTeamID()
	gameFrame = spGetGameFrame()
	local currRot = getCurrentMiniMapRotationOption()
	if lastRot ~= currRot then
		lastRot = currRot
		widget:ViewResize(vsx, vsy)
		return
	end
	if gameFrame > 1 then
		widgetHandler:RemoveWidget()
	end
	if not placeVoiceNotifTimer then
		placeVoiceNotifTimer = os.clock() + 30
	end

	if draftMode == nil or draftMode == "disabled" then -- otherwise draft mod will play it instead
		if not isSpec and not amPlaced and not playedChooseStartLoc and placeVoiceNotifTimer < os.clock() and WG['notifications'] then
			playedChooseStartLoc = true
			WG['notifications'].addEvent('ChooseStartLoc', true)
		end
	end

	sec = sec + delta
	if sec > 1 then
		sec = 0
		if assignTeamColors() then
			removeLists()
		end
	end

	if gameFrame <= 0 and Game.startPosType == 2 then
		updateCounter = updateCounter + 1
		if updateCounter % 30 == 0 then
			for k in pairs(currentPlacements) do currentPlacements[k] = nil end
			updateTeamList()

			local hasResync = false
			for _, teamID in ipairs(cachedTeamList) do
				if teamID ~= gaiaTeamID then
					local _, _, _, isAI = spGetTeamInfo(teamID, false)
					if isAI then
						local startX, _, startZ = spGetTeamStartPosition(teamID)
						if startX and startZ and startX > 0 and startZ > 0 then
							local existing = aiPlacedPositions[teamID]
							if existing then
								if existing.x ~= startX or existing.z ~= startZ then
									existing.x, existing.z = startX, startZ
									invalidatePosCacheEntry(teamID)
									hasResync = true
								end
							else
								aiPlacedPositions[teamID] = {x = startX, z = startZ}
								hasResync = true
							end
							aiPlacementStatus[teamID] = true
						else
							local aiManualPlacement = spGetTeamRulesParam(teamID, "aiManualPlacement")
							if aiManualPlacement then
								local mx, mz = string.match(aiManualPlacement, "([%d%.]+),([%d%.]+)")
								if mx and mz then
									local mxNum, mzNum = tonumber(mx), tonumber(mz)
									local existing = aiPlacedPositions[teamID]
									if existing then
										if existing.x ~= mxNum or existing.z ~= mzNum then
											existing.x, existing.z = mxNum, mzNum
											invalidatePosCacheEntry(teamID)
											hasResync = true
										end
									else
										aiPlacedPositions[teamID] = {x = mxNum, z = mzNum}
										hasResync = true
									end
									aiPlacementStatus[teamID] = true
								else
									if aiPlacedPositions[teamID] then
										aiPlacedPositions[teamID] = nil
										invalidatePosCacheEntry(teamID)
										hasResync = true
									end
									aiPlacementStatus[teamID] = false
								end
							else
								if aiPlacedPositions[teamID] then
									aiPlacedPositions[teamID] = nil
									invalidatePosCacheEntry(teamID)
									hasResync = true
								end
								aiPlacementStatus[teamID] = false
							end
						end
					end

					local x, y, z = spGetTeamStartPosition(teamID)
					local playerID = select(2, spGetTeamInfo(teamID, false))
					if coopStartPoints[playerID] then
						x, z = coopStartPoints[playerID][1], coopStartPoints[playerID][3]
					end
					if aiPlacedPositions[teamID] then
						x, z = aiPlacedPositions[teamID].x, aiPlacedPositions[teamID].z
					end
					if x and x > 0 and z and z > 0 then
						local existing = currentPlacements[teamID]
						if existing then
							existing.x, existing.z = x, z
						else
							currentPlacements[teamID] = {x = x, z = z}
						end
					end
				end
			end

			local hasChanges = hasResync
			if not hasChanges then
				for teamID, placement in pairs(currentPlacements) do
					if not lastKnownPlacements[teamID] or
					   lastKnownPlacements[teamID].x ~= placement.x or
					   lastKnownPlacements[teamID].z ~= placement.z then
						hasChanges = true
						break
					end
				end
			end

			if not hasChanges then
				for teamID, placement in pairs(lastKnownPlacements) do
					if not currentPlacements[teamID] then
						hasChanges = true
						break
					end
				end
			end

			if hasChanges then
				for k in pairs(lastKnownPlacements) do lastKnownPlacements[k] = nil end
				for teamID, placement in pairs(currentPlacements) do
					local existing = lastKnownPlacements[teamID]
					if existing then
						existing.x, existing.z = placement.x, placement.z
					else
						lastKnownPlacements[teamID] = {x = placement.x, z = placement.z}
					end
				end

				for k in pairs(aiPredictedPositions) do aiPredictedPositions[k] = nil end
				for k in pairs(startPointTable) do startPointTable[k] = nil end
				for teamID, placement in pairs(currentPlacements) do
					local existing = startPointTable[teamID]
					if existing then
						existing[1], existing[2] = placement.x, placement.z
					else
						startPointTable[teamID] = {placement.x, placement.z}
					end
				end

				for _, teamID in ipairs(cachedTeamList) do
					if teamID ~= gaiaTeamID then
						local _, _, _, isAI, _, allyTeamID = spGetTeamInfo(teamID, false)
						if isAI and not aiPlacedPositions[teamID] and (allyTeamID == myAllyTeamID or isSpec or Spring.IsCheatingEnabled() or allowEnemyAIPlacement) then
							local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(allyTeamID)
							local x, z = GuessStartSpot(teamID, allyTeamID, xmin, zmin, xmax, zmax, startPointTable)
							if x and x > 0 and z and z > 0 then
								local prevPos = aiPredictedPositions[teamID]
								if not prevPos or prevPos.x ~= x or prevPos.z ~= z then
									local existing = aiPredictedPositions[teamID]
									if existing then
										existing.x, existing.z = x, z
									else
										aiPredictedPositions[teamID] = {x = x, z = z}
									end
									invalidatePosCacheEntry(teamID)
									hasChanges = true
								end
							end
						end
					end
				end

				if hasChanges then
					notifySpawnPositionsChanged()
				end
			end
		end
	end
end

function widget:RecvLuaMsg(msg)
	if string.sub(msg, 1, 16) == "aiPlacementMode:" then
		local teamID = tonumber(string.sub(msg, 17))
		if teamID then
			aiCurrentlyBeingPlaced = teamID
		end
	elseif string.sub(msg, 1, 18) == "aiPlacementCancel:" then
		aiCurrentlyBeingPlaced = nil
	elseif string.sub(msg, 1, 20) == "aiPlacementComplete:" then
		local data = string.sub(msg, 21)
		local teamID, x, z = string.match(data, "(%d+):([%d%.]+):([%d%.]+)")
		if teamID and x and z then
			teamID = tonumber(teamID)
			x = tonumber(x)
			z = tonumber(z)
			if x == 0 and z == 0 then
				aiPlacedPositions[teamID] = nil
				aiPlacementStatus[teamID] = false
				invalidatePosCacheEntry(teamID)
				aiLocationI18NTable.playerName = spGetPlayerInfo(Spring.GetMyPlayerID(), false)
				aiLocationI18NTable.aiName = getAIName(teamID)
				Spring.SendMessage(Spring.I18N('ui.startbox.aiStartLocationRemoved', aiLocationI18NTable))
			else
				aiPlacedPositions[teamID] = {x = x, z = z}
				aiPlacementStatus[teamID] = true
				invalidatePosCacheEntry(teamID)
				aiLocationI18NTable.playerName = spGetPlayerInfo(Spring.GetMyPlayerID(), false)
				aiLocationI18NTable.aiName = getAIName(teamID)
				Spring.SendMessage(Spring.I18N('ui.startbox.aiStartLocationChanged', aiLocationI18NTable))
			end

			notifySpawnPositionsChanged()
		end
	end
end

function widget:MousePress(x, y, button)
	if gameFrame > 0 then
		return false
	end

	if draggingTeamID and button ~= LEFT_BUTTON then
		draggingTeamID = nil
		dragOffsetX = 0
		dragOffsetZ = 0
		return true
	end

	if button ~= LEFT_BUTTON and button ~= RIGHT_BUTTON then
		return false
	end

	local traceType, pos = Spring.TraceScreenRay(x, y, true)
	if traceType ~= "ground" then
		return false
	end
	local worldX, worldY, worldZ = pos[1], pos[2], pos[3]

	if button == RIGHT_BUTTON then
		if aiCurrentlyBeingPlaced then
			aiCurrentlyBeingPlaced = nil
			Spring.SendLuaUIMsg("aiPlacementCancel:")
			return true
		end

		for teamID, placedPos in pairs(aiPlacedPositions) do
			if placedPos.x and placedPos.z then
				local _, _, _, isAI, _, aiAllyTeamID = spGetTeamInfo(teamID, false)
				if isAI and (aiAllyTeamID == myAllyTeamID or allowEnemyAIPlacement) then
					local dx = worldX - placedPos.x
					local dz = worldZ - placedPos.z
					if (dx * dx + dz * dz) <= (CONE_CLICK_RADIUS * CONE_CLICK_RADIUS) then
						aiPlacedPositions[teamID] = nil
						Spring.SendLuaRulesMsg("aiPlacedPosition:" .. teamID .. ":0:0")
						Spring.SendLuaUIMsg("aiPlacementComplete:" .. teamID .. ":0:0")
						return true
					end
				end
			end
		end
		return false
	end

	if aiCurrentlyBeingPlaced then
		local aiTeamID = aiCurrentlyBeingPlaced
		local _, _, _, _, _, aiAllyTeamID = spGetTeamInfo(aiTeamID, false)

		local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(aiAllyTeamID)
		if xmin < xmax and zmin < zmax then
			if worldX >= xmin and worldX <= xmax and worldZ >= zmin and worldZ <= zmax then
				Spring.SendLuaRulesMsg("aiPlacedPosition:" .. aiTeamID .. ":" .. worldX .. ":" .. worldZ)
				aiCurrentlyBeingPlaced = nil
				return true
			end
		end
		return false
	end

	for _, teamID in ipairs(cachedTeamList) do
		local _, _, _, isAI, _, aiAllyTeamID = spGetTeamInfo(teamID, false)
		if isAI and (aiAllyTeamID == myAllyTeamID or allowEnemyAIPlacement) then
			local coneX, coneZ
			local placedPos = aiPlacedPositions[teamID]
			local predictedPos = aiPredictedPositions[teamID]

			if placedPos and placedPos.x and placedPos.z then
				coneX, coneZ = placedPos.x, placedPos.z
			elseif predictedPos and predictedPos.x and predictedPos.z then
				coneX, coneZ = predictedPos.x, predictedPos.z
			end

			if coneX and coneZ then
				local dx = worldX - coneX
				local dz = worldZ - coneZ
				if (dx * dx + dz * dz) <= (CONE_CLICK_RADIUS * CONE_CLICK_RADIUS) then
					draggingTeamID = teamID
					dragOffsetX = coneX - worldX
					dragOffsetZ = coneZ - worldZ
					return true
				end
			end
		end
	end

	return false
end

function widget:MouseRelease(x, y, button)
	if gameFrame > 0 then
		return false
	end

	if button == LEFT_BUTTON and draggingTeamID then
		local traceType, pos = Spring.TraceScreenRay(x, y, true)
		if traceType == "ground" then
			local worldX, worldY, worldZ = pos[1], pos[2], pos[3]
			local finalX = worldX + dragOffsetX
			local finalZ = worldZ + dragOffsetZ

			local _, _, _, _, _, aiAllyTeamID = spGetTeamInfo(draggingTeamID, false)
			local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(aiAllyTeamID)

			if xmin < xmax and zmin < zmax then
				if finalX >= xmin and finalX <= xmax and finalZ >= zmin and finalZ <= zmax then
					aiPlacedPositions[draggingTeamID] = {x = finalX, z = finalZ}
					posCache[draggingTeamID] = nil
					Spring.SendLuaRulesMsg("aiPlacedPosition:" .. draggingTeamID .. ":" .. finalX .. ":" .. finalZ)
					notifySpawnPositionsChanged()
				end
			end
		end

		draggingTeamID = nil
		dragOffsetX = 0
		dragOffsetZ = 0
		return true
	end

	return false
end
