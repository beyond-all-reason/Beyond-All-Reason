function widget:GetInfo()
	return {
		name = "Start Boxes",
		desc = "Displays Start Boxes and Start Points",
		author = "trepan, jK",
		date = "2007-2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local getMiniMapFlipped = VFS.Include("luaui/Widgets/Include/minimap_utils.lua").getMiniMapFlipped

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

local widgetScale = (1 + (vsx * vsy / 5500000))

local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local xformList = 0
local coneList = 0
local startboxDListStencil = 0
local startboxDListColor = 0

local isSpec = Spring.GetSpectatingState() or Spring.IsReplay()
local myTeamID = Spring.GetMyTeamID()

local flipped = false

local placeVoiceNotifTimer = false
local playedChooseStartLoc = false
local amPlaced = false

local gaiaTeamID
local gaiaAllyTeamID

local startTimer = Spring.GetTimer()

local infotextList

local GetTeamColor = Spring.GetTeamColor

local glTranslate = gl.Translate
local glCallList = gl.CallList

GL.KEEP = 0x1E00
GL.INCR_WRAP = 0x8507
GL.DECR_WRAP = 0x8508
GL.INCR = 0x1E02
GL.DECR = 0x1E03
GL.INVERT = 0x150A

local stencilBit1 = 0x01
local stencilBit2 = 0x10
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
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
end

local function DrawMyBox(minX, minY, minZ, maxX, maxY, maxZ)
	gl.BeginEnd(GL.QUADS, function()
		--// top
		gl.Vertex(minX, maxY, minZ)
		gl.Vertex(maxX, maxY, minZ)
		gl.Vertex(maxX, maxY, maxZ)
		gl.Vertex(minX, maxY, maxZ)
		--// bottom
		gl.Vertex(minX, minY, minZ)
		gl.Vertex(minX, minY, maxZ)
		gl.Vertex(maxX, minY, maxZ)
		gl.Vertex(maxX, minY, minZ)
	end)
	gl.BeginEnd(GL.QUAD_STRIP, function()
		--// sides
		gl.Vertex(minX, minY, minZ)
		gl.Vertex(minX, maxY, minZ)
		gl.Vertex(minX, minY, maxZ)
		gl.Vertex(minX, maxY, maxZ)
		gl.Vertex(maxX, minY, maxZ)
		gl.Vertex(maxX, maxY, maxZ)
		gl.Vertex(maxX, minY, minZ)
		gl.Vertex(maxX, maxY, minZ)
		gl.Vertex(minX, minY, minZ)
		gl.Vertex(minX, maxY, minZ)
	end)
end

local function createCommanderNameList(x, y, name, teamID)
	commanderNameList[teamID] = {}
	commanderNameList[teamID]['x'] = math.floor(x)
	commanderNameList[teamID]['y'] = math.floor(y)
	commanderNameList[teamID]['list'] = gl.CreateList(function()
		local r, g, b = GetTeamColor(teamID)
		local outlineColor = { 0, 0, 0, 1 }
		if (r + g * 1.2 + b * 0.4) < 0.65 then
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
	if commanderNameList[teamID] == nil or commanderNameList[teamID]['x'] ~= math.floor(x) or commanderNameList[teamID]['y'] ~= math.floor(y) then
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

local function drawFormList()
	gl.LoadIdentity()
	if flipped then -- minimap is flipped
		gl.Translate(1, 0, 0)
		gl.Scale(-1 / msx, 1 / msz, 1)
	else
		gl.Translate(0, 1, 0)
		gl.Scale(1 / msx, -1 / msz, 1)
	end
end

---------------------------------- StartPolygons ----------------------------------
-- Note: this is now updated to support arbitrary start polygons via GL.SHADER_STORAGE_BUFFER

-- The format of the buffer is the following:
-- Triplets of :teamID, triangleID, x, z

-- Spring.Echo(Spring.GetTeamInfo(Spring.GetMyTeamID()))

-- TODO:
-- [ ] Handle overlapping of boxes and myAllyTeamID
-- [X] Handle Minimap drawing too 
	-- [X] handle flipped minimaps 
-- [ ] Pass in my team too
-- [ ] Handle Scavengers in scavenger color
-- [ ] Handle Raptors in raptor color

local scavengerStartBoxTexture = "LuaUI/Images/scav-tileable_v002_small.tga"

local raptorStartBoxTexture = "LuaUI/Images/rapt-tileable_v002_small.tga"

local getMiniMapFlipped = VFS.Include("luaui/Widgets/Include/minimap_utils.lua").getMiniMapFlipped


local scavengerAIAllyTeamID
local raptorsAIAllyTeamID
local teams = Spring.GetTeamList()

for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		local scavengerAITeamID = i - 1
		scavengerAIAllyTeamID = select(6, Spring.GetTeamInfo(scavengerAITeamID))
		break
	end
end
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'RaptorsAI' then
		local raptorsAITeamID = i - 1
		raptorsAIAllyTeamID = select(6, Spring.GetTeamInfo(raptorsAITeamID))
		break
	end
end
---- Config stuff ------------------
local autoReload = false -- refresh shader code every second (disable in production!)

local StartPolygons = {} -- list of points in clockwise order

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local minY, maxY = Spring.GetGroundExtremes()

local shaderSourceCache = {
		vssrcpath = "LuaUI/Widgets/Shaders/map_startpolygon_gl4.vert.glsl",
		fssrcpath = "LuaUI/Widgets/Shaders/map_startpolygon_gl4.frag.glsl",
		uniformInt = {
			mapDepths = 0,
			myAllyTeamID = -1,
			isMiniMap = 0,
			flipMiniMap = 0,
			mapNormals = 1,
			heightMapTex = 2, 
			scavTexture = 3,
			raptorTexture = 4,
		},
		uniformFloat = {
			pingData = {0,0,0,-10000}, -- x,y,z, time
		},
		shaderName = "Start Polygons GL4",
		shaderConfig = {
			ALPHA = 0.5,
			NUM_POLYGONS = 0,
			NUM_POINTS = 0,
			MINY = minY - 10,
			MAXY = maxY + 100,
			MAX_STEEPNESS = math.cos(math.rad(54)),
			SCAV_ALLYTEAM_ID = scavengerAIAllyTeamID, -- these neatly become undefined if not present
			RAPTOR_ALLYTEAM_ID = raptorsAIAllyTeamID,
		},
		silent = (not autoReload),
	}

local fullScreenRectVAO
local startPolygonShader
local startPolygonBuffer = nil -- GL.SHADER_STORAGE_BUFFER for polygon

local function DrawStartPolygons(inminimap)	
	local advUnitShading, advMapShading = Spring.HaveAdvShading()

	if advMapShading then 
		gl.Texture(0, "$map_gbuffer_zvaltex")
	else
		if WG['screencopymanager'] and WG['screencopymanager'].GetDepthCopy() then
			gl.Texture(0, WG['screencopymanager'].GetDepthCopy())
		else 
			Spring.Echo("Start Polygons: Adv map shading not available, and no depth copy available")
			return
		end
	end
	
	gl.Texture(1, "$normals")
	gl.Texture(2, "$heightmap")-- Texture file
	gl.Texture(3, scavengerStartBoxTexture)
	gl.Texture(4, raptorStartBoxTexture)

	startPolygonBuffer:BindBufferRange(4)

	gl.Culling(GL.FRONT)
	gl.DepthTest(false)
	gl.DepthMask(false)

	startPolygonShader:Activate()

	startPolygonShader:SetUniform("noRushTimer", noRushTime)
	startPolygonShader:SetUniformInt("isMiniMap", inminimap and 1 or 0)
	startPolygonShader:SetUniformInt("flipMiniMap", getMiniMapFlipped() and 1 or 0)
	startPolygonShader:SetUniformInt("myAllyTeamID", Spring.GetMyAllyTeamID() or -1) 

	fullScreenRectVAO:DrawArrays(GL.TRIANGLES)
	startPolygonShader:Deactivate()
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)
	gl.Texture(4, false)
	gl.Culling(GL.BACK)
	gl.DepthTest(false)
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
			--Spring.Echo("Allyteam",teamID,"startbox",xn, zn, xp, zp)	
			StartPolygons[teamID] = {{xn, zn}, {xp, zn}, {xp, zp}, {xn, zp}}
		end
	end
	
	if autoReload and false then
		-- MANUAL OVERRIDE FOR DEBUGGING
		-- lets add a bunch of silly StartPolygons:
		StartPolygons = {}
		for i = 2,8 do
			local x0 = math.random(0, Game.mapSizeX)
			local y0 = math.random(0, Game.mapSizeZ)
			local polygon = {{x0, y0}}

			for j = 2, math.ceil(math.random() * 10) do 
				local x1 = math.random(0, Game.mapSizeX / 5)
				local y1 = math.random(0, Game.mapSizeZ / 5)
				polygon[#polygon+1] = {x0+x1, y0+y1}
			end
			StartPolygons[#StartPolygons+1] = polygon
		end
	end

	shaderSourceCache.shaderConfig.NUM_BOXES = #StartPolygons

	local numvertices = 0
	local bufferdata = {}
	local numPolygons = 0
	for teamID, polygon in pairs(StartPolygons) do
		numPolygons = numPolygons + 1
		local numPoints = #polygon
		local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(teamID)
		--Spring.Echo("teamID", teamID, "at " ,xn, zn, xp, zp)
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
		Spring.Echo("Error: Norush Timer GL4 shader not initialized")
		widgetHandler:RemoveWidget()
		return
	end
	fullScreenRectVAO = MakeTexRectVAO()

end	

--------------------------------------------------------------------------------

function widget:Initialize()
	-- only show at the beginning
	if Spring.GetGameFrame() > 1 then
		widgetHandler:RemoveWidget()
		return
	end

	widgetHandler:RegisterGlobal('GadgetCoopStartPoint', CoopStartPoint)

	assignTeamColors()

	gaiaTeamID = Spring.GetGaiaTeamID()
	if gaiaTeamID then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))
	end

	-- flip and scale  (using x & y for gl.Rect())
	xformList = gl.CreateList(drawFormList)

	-- cone list for world start positions
	coneList = gl.CreateList(function()
		local h = 100
		local r = 25
		local divs = 32
		gl.BeginEnd(GL.TRIANGLE_FAN, function()
			gl.Vertex(0, h, 0)
			for i = 0, divs do
				local a = i * ((math.pi * 2) / divs)
				local cosval = math.cos(a)
				local sinval = math.sin(a)
				gl.Vertex(r * sinval, 0, r * cosval)
			end
		end)
	end)
	local waterlevel = 0
	if Spring.GetModOptions().map_waterlevel ~= 0 then
		waterlevel = Spring.GetModOptions().map_waterlevel
	end

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
	gl.DeleteList(xformList)
	gl.DeleteList(coneList)
	gl.DeleteList(startboxDListStencil)
	gl.DeleteList(startboxDListColor)
	removeTeamLists()
end

function widget:Shutdown()
	removeLists()
	gl.DeleteFont(font)
	gl.DeleteFont(shadowFont)
	widgetHandler:DeregisterGlobal('GadgetCoopStartPoint')
end

local function DrawStartboxes3dWithStencil()
	gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
	if gl.DepthClamp then
		gl.DepthClamp(true)
	end

	gl.DepthTest(true)
	gl.StencilTest(true)
	gl.ColorMask(false, false, false, false)
	gl.Culling(false)

	gl.StencilOp(GL.KEEP, GL.INVERT, GL.KEEP)

	gl.CallList(startboxDListStencil)   --// draw

	gl.Culling(GL.BACK)
	gl.DepthTest(false)

	gl.ColorMask(true, true, true, true)

	gl.CallList(startboxDListColor)   --// draw

	if gl.DepthClamp then
		gl.DepthClamp(false)
	end
	gl.StencilTest(false)
	gl.DepthTest(true)
	gl.Culling(false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawWorldPreUnit()
	if autoReload then
		startPolygonShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or startPolygonShader
	end
	DrawStartPolygons(false)
end

function widget:DrawWorld()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)


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
				gl.PushMatrix()
				gl.Translate(x, y, z)
				gl.Color(r, g, b, alpha)
				gl.CallList(coneList)
				gl.PopMatrix()
				if teamID == myTeamID then
					amPlaced = true
				end
			end
		end
	end
end

function widget:DrawScreenEffects()
	-- show the names over the team start positions
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local playerID = select(2, Spring.GetTeamInfo(teamID, false))
		local name, _, spec = Spring.GetPlayerInfo(playerID, false)
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
	if Spring.GetGameFrame() > 1 then
		widgetHandler:RemoveWidget()
	end

	gl.PushMatrix()
	gl.CallList(xformList)
	gl.LineWidth(1.49)

	local gaiaAllyTeamID
	local gaiaTeamID = Spring.GetGaiaTeamID()
	if gaiaTeamID then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))
	end

	-- show all start boxes
	DrawStartPolygons(true)

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
				local time = Spring.DiffTimers(Spring.GetTimer(), startTimer)
				local i = 2 * math.abs(((time * 3) % 1) - 0.5)
				gl.PointSize(11)
				gl.Color(i, i, i)
				gl.BeginEnd(GL.POINTS, gl.Vertex, x, z)
				gl.PointSize(7.5)
				gl.Color(r, g, b)
				gl.BeginEnd(GL.POINTS, gl.Vertex, x, z)
			end
		end
	end

	gl.LineWidth(1.0)
	gl.PointSize(1.0)
	gl.PopMatrix()
end

function widget:ViewResize(x, y)
	vsx, vsy = x, y
	widgetScale = (0.75 + (vsx * vsy / 7500000))
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
local resetsec = 0
local resetted = false
local doWaterLevelCheck = false
if Spring.GetModOptions().map_waterlevel ~= 0 then
	doWaterLevelCheck = true
end

local groundHeightPoint = Spring.GetGroundHeight(0, 0)
local sec = 0
function widget:Update(delta)
	if Spring.GetGameFrame() > 1 then
		widgetHandler:RemoveWidget()
	end
	if not placeVoiceNotifTimer then
		placeVoiceNotifTimer = os.clock() + 30
	end

	if (doWaterLevelCheck and not resetted) or (Spring.IsCheatingEnabled() and Spring.GetGroundHeight(0, 0) ~= groundHeightPoint) then
		resetsec = resetsec + delta
		if resetsec > 1 then
			groundHeightPoint = Spring.GetGroundHeight(0, 0)
			resetted = true
			removeLists()
			widget:Initialize()
		end
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

		local newFlipped = getMiniMapFlipped()
		if flipped ~= newFlipped then
			flipped = newFlipped
			gl.DeleteList(xformList)
			xformList = gl.CreateList(drawFormList)
		end

		if detectedChanges then
			removeLists()
		end
	end
end
