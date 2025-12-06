local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Start Boxes",
		desc = "Displays Start Boxes and Start Points",
		author = "trepan, jK, Beherith",
		date = "2007-2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		depends = {'gl4'}
	}
end

if Spring.GetModOptions().experimental_ai_spawns then
	return false
end

-- Localized functions for performance
local mathFloor = math.floor
local mathRandom = math.random

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spEcho = Spring.Echo
local spGetSpectatingState = Spring.GetSpectatingState

local getCurrentMiniMapRotationOption = VFS.Include("luaui/Include/minimap_utils.lua").getCurrentMiniMapRotationOption
local ROTATION = VFS.Include("luaui/Include/minimap_utils.lua").ROTATION

if Game.startPosType ~= 2 then
	return false
end

local draftMode = Spring.GetModOptions().draft_mode

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
local usedFontSize = fontSize
spEcho(Spring.GetMiniMapGeometry())
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

local hasStartbox = false

local teamColors = {}
local coopStartPoints = {}	-- will contain data passed through by coop gadget

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function assignTeamColors()
	local teams = Spring.GetTeamList()
	for _, teamID in pairs(teams) do
		local r, g, b = GetTeamColor(teamID)
		teamColors[teamID] = r .. "_" .. g  .. "_" ..  b
	end
end

function widget:PlayerChanged(playerID)
	isSpec = spGetSpectatingState()
	myTeamID = spGetMyTeamID()
end

local function createCommanderNameList(x, y, name, teamID)
	commanderNameList[teamID] = {}
	commanderNameList[teamID]['x'] = mathFloor(x)
	commanderNameList[teamID]['y'] = mathFloor(y)
	commanderNameList[teamID]['list'] = gl.CreateList(function()
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
	-- not optimal, everytime you move camera the x and y are different so it has to recreate the drawlist
	if commanderNameList[teamID] == nil or commanderNameList[teamID]['x'] ~= mathFloor(x) or commanderNameList[teamID]['y'] ~= mathFloor(y) then
		-- using floor because the x and y values had a a tiny change each frame
		if commanderNameList[teamID] ~= nil then
			gl.DeleteList(commanderNameList[teamID]['list'])
		end
		createCommanderNameList(x, y, name, teamID)
	end
	glCallList(commanderNameList[teamID]['list'])
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
		if draftMode == nil or draftMode == "disabled" then
			font:Print(hasStartbox and infotextBoxes or infotext, 0, 0, infotextFontsize * widgetScale, "cno")
		end
		font:End()
	end)
end

local function CoopStartPoint(playerID, x, y, z)
	coopStartPoints[playerID] = {x, y, z}
end

function widget:LanguageChanged()
	createInfotextList()
end


---------------------------------- StartPolygons ----------------------------------
-- Note: this is now updated to support arbitrary start polygons via GL.SHADER_STORAGE_BUFFER

-- The format of the buffer is the following:
-- Triplets of :teamID, triangleID, x, z

-- spEcho(Spring.GetTeamInfo(spGetMyTeamID()))

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
	startPolygonShader:SetUniformInt("myAllyTeamID", Spring.GetMyAllyTeamID() or -1)

	fullScreenRectVAO:DrawArrays(GL.TRIANGLES)
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

	startConeShader:SetUniformFloat("startPosScale", startPosScale)

	startConeVBOTable:draw()
	startConeShader:Deactivate()
end


local function InitStartPolygons()
	local gaiaAllyTeamID
	if Spring.GetGaiaTeamID() then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID() , false))
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

	startPolygonBuffer = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false) -- not updated a lot
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
	-- only show at the beginning
	if spGetGameFrame() > 1 then
		widgetHandler:RemoveWidget()
		return
	end

	widgetHandler:RegisterGlobal('GadgetCoopStartPoint', CoopStartPoint)

	assignTeamColors()

	gaiaTeamID = Spring.GetGaiaTeamID()

	createInfotextList()

	InitStartPolygons()
end

local function removeTeamLists()
	for _, teamID in ipairs(Spring.GetTeamList()) do
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
function widget:DrawWorld()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)

	InstanceVBOTable.clearInstanceTable(startConeVBOTable)
	-- show the team start positions
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local playerID = select(2, Spring.GetTeamInfo(teamID, false))
		local _, _, spec = Spring.GetPlayerInfo(playerID, false)
		if not spec and teamID ~= gaiaTeamID then
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			if coopStartPoints[playerID] then
				x, y, z = coopStartPoints[playerID][1], coopStartPoints[playerID][2], coopStartPoints[playerID][3]
			end
			if x ~= nil and x > 0 and z > 0 and y > -500 then
				local r, g, b = GetTeamColor(teamID)
				local alpha = 0.5 + math.abs(((time * 3) % 1) - 0.5)
				cacheTable[1], cacheTable[2], cacheTable[3], cacheTable[4] = x, y, z, 1
				cacheTable[5], cacheTable[6], cacheTable[7], cacheTable[8] = r, g, b, alpha
				pushElementInstance(startConeVBOTable,
					cacheTable,
					nil, nil, true)
				if teamID == myTeamID then
					amPlaced = true
				end
			end
		end
	end


	InstanceVBOTable.uploadAllElements(startConeVBOTable)

	DrawStartCones(false)
end

function widget:DrawScreenEffects()
	-- show the names over the team start positions
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local playerID = select(2, Spring.GetTeamInfo(teamID, false))
		local name, _, spec = Spring.GetPlayerInfo(playerID, false)
		name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or name
		if name ~= nil and not spec and teamID ~= gaiaTeamID then
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			if coopStartPoints[playerID] then
				x, y, z = coopStartPoints[playerID][1], coopStartPoints[playerID][2], coopStartPoints[playerID][3]
			end
			if x ~= nil and x > 0 and z > 0 and y > -500 then
				local sx, sy, sz = Spring.WorldToScreenCoords(x, y + 120, z)
				if sz < 1 then
					drawName(sx, sy, name, teamID)
				end
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
	if spGetGameFrame() > 1 then
		widgetHandler:RemoveWidget()
	end

	DrawStartPolygons(true)
	DrawStartCones(true)
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
function widget:Update(delta)
	local currRot = getCurrentMiniMapRotationOption()
	if lastRot ~= currRot then
		lastRot = currRot
		widget:ViewResize(vsx, vsy)
		return
	end
	if spGetGameFrame() > 1 then
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

		-- check if team colors have changed
		local detectedChanges = false
		local oldTeamColors = teamColors
		assignTeamColors()
		local teams = Spring.GetTeamList()
		for _, teamID in pairs(teams) do
			if oldTeamColors[teamID] ~= teamColors[teamID] then
				detectedChanges = true
			end
		end

		if detectedChanges then
			removeLists()
		end
	end
end
