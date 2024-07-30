function widget:GetInfo()
	return {
		name = "Start Boxes gl4",
		desc = "Displays Start Boxes and Start Points",
		author = "trepan, jK, modern gl by lov",
		date = "2007-2009, 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false
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
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale,
	fontfileOutlineStrength)
local shadowFont = gl.LoadFont(fontfile, fontfileSize * fontfileScale, 35 * fontfileScale, 1.5)
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale,
	fontfileOutlineStrength2)

local useThickLeterring = false
local fontSize = 18
local fontShadow = true -- only shows if font has a white outline
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

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
VFS.Include(luaShaderDir .. "instancevbotable.lua")
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
local coopStartPoints = {} -- will contain data passed through by coop gadget

local startboxVAOs = {}
local startposData = {}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local startboxShader
local startboxVS = [[
  #version 420
  #line 10000
  //__DEFINES__
  layout (location = 0) in vec4 wpos;

  uniform sampler2D heightmapTex;
  out DataVS {
    vec3 worldPos;
  };
  //__ENGINEUNIFORMBUFFERDEFS__
  #line 11000
  float heightAtWorldPos(vec2 w){
    vec2 uvhm = vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy;
    return textureLod(heightmapTex, uvhm, 0.0).x;
  }
  void main() {
    worldPos = wpos.xyz;
    // gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
	// gl_Position = cameraViewProj * vec4(wpos.x, heightAtWorldPos(wpos.xy)+10, wpos.y, 1.0);
	gl_Position = cameraViewProj * vec4(wpos.xyz, 1.0);
  }
	]]
local startboxFS = [[
#version 330
  #extension GL_ARB_uniform_buffer_object : require
  #extension GL_ARB_shading_language_420pack: require
  #line 20000
  in vec4 gl_FragCoord;
  uniform sampler2D heightmapTex;
  uniform float elatime;
  uniform vec4 bounds;
  uniform vec4 color;
  //__ENGINEUNIFORMBUFFERDEFS__
  //__DEFINES__
  in DataVS {
    vec3 worldPos;
  };
  out vec4 fragColor;
  float heightAtWorldPos(vec2 w){
    vec2 uvhm = vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy;
    return textureLod(heightmapTex, uvhm, 0.0).x;
  }
  void main() {
	float rect_x = bounds.x;
    float rect_y = bounds.y;
    float rect_width = bounds.z;//-bounds.x;
    float rect_height = bounds.w;//-bounds.y;

	float minX = min(abs(rect_x - worldPos.x), abs(rect_width - worldPos.x));
	float minY = min(abs(rect_y - worldPos.z), abs(rect_height - worldPos.z));
	float minDist = min(minX, minY);
	float range = 400-sin(elatime)*100;
	float scaler = 1-clamp(minDist,0,range)/range;
	//scaler = scaler + sin((30*elatime-worldPos.z/10)/40);

	//fragColor = vec4(0.0,(smoothstep(0,1,sin(-2.0*elatime+worldPos.z/100))+2)*minDist,0.0,0.2);
	fragColor = vec4(0.0,.7,0.0,0.4);
	fragColor = vec4(color.xyz,color.w*scaler+.07);
	//fragColor = vec4(0,1,0,.3*pass);
  }
	]]
local startposShader
local startposVS = [[
  #version 420
  #line 10000
  //__DEFINES__
  layout (location = 0) in vec4 pos;
  layout (location = 1) in vec3 wpos;
  layout (location = 2) in vec4 teamcolor;


  uniform sampler2D heightmapTex;
  //uniform sampler2D hexTex;
  out DataVS {
    vec3 objPos;
	vec3 worldPos;
    vec4 color;
  };
  //__ENGINEUNIFORMBUFFERDEFS__
  #line 11000
  float heightAtWorldPos(vec2 w){
    vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy;
    return textureLod(heightmapTex, uvhm, 0.0).x;
  }
  void main() {
	objPos = pos.xyz;
    worldPos = wpos;
	color = teamcolor;
	gl_Position = cameraViewProj * (vec4(wpos.xyz*2, 1.0) + vec4(pos.xyz,1.0));
  }
	]]
local startposFS = [[
#version 330
  #extension GL_ARB_uniform_buffer_object : require
  #extension GL_ARB_shading_language_420pack: require
  #line 20000
  in vec4 gl_FragCoord;
  uniform sampler2D heightmapTex;
  uniform float elatime;
  uniform float height;
  //__ENGINEUNIFORMBUFFERDEFS__
  //__DEFINES__
  in DataVS {
    vec3 objPos;
    vec3 worldPos;
    vec4 color;
  };
  out vec4 fragColor;
  float heightAtWorldPos(vec2 w){
    vec2 uvhm = vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy;
    return textureLod(heightmapTex, uvhm, 0.0).x;
  }
  void main() {
	float range = 400-sin(elatime)*100;
	float height01 = 1-objPos.y/height;
	float heightfade = height01*height01;//*height01;
	float scaler = heightfade+heightfade*((sin(elatime+objPos.y/100))+.3)*.5;
	float cutzero = sign(objPos.y);
	fragColor = vec4(color.xyz, scaler*cutzero);
  }
	]]

local function goodbye(reason)
	Spring.Echo("DefenseRange GL4 widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function assignTeamColors()
	local teams = Spring.GetTeamList()
	for _, teamID in pairs(teams) do
		local r, g, b = GetTeamColor(teamID)
		teamColors[teamID] = r .. "_" .. g .. "_" .. b
	end
end

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
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
		font2:SetTextColor({ r, g, b })
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
	coopStartPoints[playerID] = { x, y, z }
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

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	startboxShader = LuaShader(
		{
			vertex = startboxVS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			fragment = startboxFS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			uniformInt = {
				heightmapTex = 0,
			},
			uniformFloat = {
				elatime = 0,
				color = { 0, 0, 0, 0 },
				bounds = { 0, 0, 0, 0 }
			}
		}
	)
	local success = startboxShader:Initialize()
	if not success then
		goodbye("Failed to compile startbox GL4 ")
		return false
	end
	local coneHeight = 900
	startposShader = LuaShader(
		{
			vertex = startposVS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			fragment = startposFS:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			uniformInt = {
				heightmapTex = 0,
			},
			uniformFloat = {
				elatime = 0,
				height = coneHeight
			}
		}
	)
	success = startposShader:Initialize()
	if not success then
		goodbye("Failed to compile startpos GL4 ")
		return false
	end

	local minY, maxY = Spring.GetGroundExtremes()


	for _, at in ipairs(Spring.GetAllyTeamList()) do
		local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
		if zn > zp then
			local temp = zn
			zn = zp
			zp = temp
		end
		zp = math.min(msz, zp)
		xp = math.min(msx, xp)
		if xn and (xn ~= 0 or zn ~= 0 or xp ~= msx or zp ~= msz) then
			local someVAO = gl.GetVAO() --get empty VAO
			local boxVBO, numVertices = makeBoxVBO(xn, minY, zn, xp, maxY, zp)

			someVAO:AttachVertexBuffer(boxVBO)
			local indxVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)

			indxVBO:Define(numVertices, GL.UNSIGNED_INT)
			local indices = {}
			for i = 1, numVertices do
				indices[i] = i - 1
			end
			indxVBO:Upload(indices)
			someVAO:AttachIndexBuffer(indxVBO)
			local boxcolor = { .7, 0, 0, .3 }
			if at == Spring.GetMyAllyTeamID() then
				boxcolor = { 0, .7, 0, .3 }
			end
			startboxVAOs[at] = { color = boxcolor, vao = someVAO, bounds = { xn, zn, xp, zp }, vertCount = numVertices }
		end
	end

	local someVAO = gl.GetVAO() --get empty VAO
	local coneVBO, numVertices = makeConeVBO(32, coneHeight, 70)

	someVAO:AttachVertexBuffer(coneVBO)
	local indxVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)

	indxVBO:Define(numVertices, GL.UNSIGNED_INT)
	local indices = {}
	for i = 1, numVertices do
		indices[i] = i - 1
	end
	indxVBO:Upload(indices)
	someVAO:AttachIndexBuffer(indxVBO)

	local teamlist = Spring.GetTeamList()
	local posInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	posInstanceVBO:Define(#teamlist * 7, {
		{ id = 1, name = "wpos",  size = 3 },
		{ id = 2, name = "color", size = 4 },
	})

	someVAO:AttachInstanceBuffer(posInstanceVBO)
	startposData.vao = someVAO
	startposData.vertCount = numVertices
	startposData.instanceVBO = posInstanceVBO

	createInfotextList()
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
	removeTeamLists()
end

function widget:Shutdown()
	removeLists()
	gl.DeleteFont(font)
	gl.DeleteFont(shadowFont)
	widgetHandler:DeregisterGlobal('GadgetCoopStartPoint')
end

local function DrawStartboxes3dWithStencil(vaoObj)
	gl.DepthMask(false)
	if gl.DepthClamp then
		gl.DepthClamp(true)
	end

	gl.Clear(GL.DEPTH_BUFFER_BIT)
	gl.Clear(GL.STENCIL_BUFFER_BIT)
	gl.ColorMask(false, false, false, false)
	gl.Culling(false)
	gl.DepthTest(true)

	gl.StencilTest(true)
	gl.StencilMask(stencilBit2)
	gl.StencilFunc(GL.ALWAYS, stencilBit2, stencilBit2)
	gl.StencilOp(GL.KEEP, GL.INVERT, GL.KEEP)

	gl.Texture(0, "$heightmap")
	startboxShader:Activate()
	startboxShader:SetUniformFloat("bounds", vaoObj.bounds[1], vaoObj.bounds[2], vaoObj.bounds[3], vaoObj.bounds[4])
	startboxShader:SetUniformFloat("color", vaoObj.color[1], vaoObj.color[2], vaoObj.color[3], vaoObj.color[4])
	startboxShader:SetUniformFloat("elatime", os.clock()) -- unused
	vaoObj.vao:DrawElements(GL.TRIANGLES, vaoObj.vertCount, 0, 0, 0)
	gl.Culling(GL.FRONT)
	gl.DepthTest(false)

	gl.ColorMask(true, true, true, true)
	gl.StencilFunc(GL.EQUAL, stencilBit2, stencilBit2)
	gl.StencilOp(GL.KEEP, GL.KEEP, GL.KEEP)
	vaoObj.vao:DrawElements(GL.TRIANGLES, vaoObj.vertCount, 0, 0, 0)
	startboxShader:Deactivate()
	gl.Texture(0, false)

	-- reset stencil test
	gl.StencilTest(false)
	gl.StencilMask(255)
	-- gl.StencilOp(GL.KEEP, GL.KEEP, GL.KEEP)
	gl.Clear(GL.STENCIL_BUFFER_BIT)

	if gl.DepthClamp then
		gl.DepthClamp(false)
	end
	gl.DepthTest(true)
	gl.Culling(false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawWorld()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- show the ally startboxes
	for _, at in ipairs(Spring.GetAllyTeamList()) do
		if startboxVAOs[at] ~= nil then
			DrawStartboxes3dWithStencil(startboxVAOs[at])
		end
	end


	local teamlist = Spring.GetTeamList()
	local startboxInstanceData = {}
	local spcount= 0
	for _, teamID in ipairs(teamlist) do
		local playerID = select(2, Spring.GetTeamInfo(teamID, false))
		local _, _, spec = Spring.GetPlayerInfo(playerID, false)
		if not spec and teamID ~= gaiaTeamID then
			local x, y, z = Spring.GetTeamStartPosition(teamID)
			if coopStartPoints[playerID] then
				x, y, z = coopStartPoints[playerID][1], coopStartPoints[playerID][2], coopStartPoints[playerID][3]
			end
			if x ~= nil and x > 0 and z > 0 and y > -500 then
				spcount = spcount + 1
				local r, g, b = GetTeamColor(teamID)
				startboxInstanceData[#startboxInstanceData + 1] = x
				startboxInstanceData[#startboxInstanceData + 1] = y
				startboxInstanceData[#startboxInstanceData + 1] = z
				startboxInstanceData[#startboxInstanceData + 1] = r
				startboxInstanceData[#startboxInstanceData + 1] = g
				startboxInstanceData[#startboxInstanceData + 1] = b
				startboxInstanceData[#startboxInstanceData + 1] = .7
			end
		end
	end
	if #startboxInstanceData > 1 then
		startposData.instanceVBO:Upload(startboxInstanceData)

		startposShader:Activate()
		-- gl.Culling(GL.BACK)
		startposShader:SetUniformFloat("elatime", os.clock())
		startposData.vao:DrawElements(GL.TRIANGLES, startposData.vertCount, 0, spcount)
		-- gl.Culling(false)
		startposShader:Deactivate()
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
	for _, at in ipairs(Spring.GetAllyTeamList()) do
		if at ~= gaiaAllyTeamID then
			local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(at)
			if xn and (xn ~= 0 or zn ~= 0 or xp ~= msx or zp ~= msz) then
				local color = at == Spring.GetMyAllyTeamID() and { 0, 1, 0, 0.1 } or { 1, 0, 0, 0.1 }
				gl.Color(color)
				gl.Rect(xn, zn, xp, zp)
				color[4] = 0.5 --  pump up the volume
				gl.Color(color)
				gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
				gl.Rect(xn, zn, xp, zp)
				gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
			end
		end
	end

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
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale,
			fontfileOutlineStrength)
		font2 = gl.LoadFont(fontfile2, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale,
			fontfileOutlineStrength2)
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
