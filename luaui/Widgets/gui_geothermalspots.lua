local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Geothermalspots",
		desc    = "Displays rotating circles around geothermal spots",
		author  = "Floris, Beherith GL4",
		date    = "August 2021",
		license = "Lua GNU GPL, v2 or later,   GLSL: (c) Beherith (mysterme@gmail.com)",
		layer   = 2,
		enabled = true,
	}
end


local showValue			= false
local metalViewOnly		= false

local circleSpaceUsage	= 0.82
local circleInnerOffset	= 0
local opacity			= 0.5

local innersize			= 3.0		-- outersize-innersize = circle width
local outersize			= 3.32		-- outersize-innersize = circle width

local spIsGUIHidden = Spring.IsGUIHidden
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMapDrawMode  = Spring.GetMapDrawMode

local spots = {}
local previousOsClock = os.clock()
local checkspots = true
local sceduledCheckedSpotsFrame = Spring.GetGameFrame()

local isSpec, fullview = Spring.GetSpectatingState()
local myAllyTeamID = Spring.GetMyAllyTeamID()

local chobbyInterface

local function spotKey(x, z)
	return tostring(x).."_"..tostring(z)
end

local extractors = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.needGeo then
		extractors[uDefID] = true
	end
end

local showGeothermalUnits = false
local function checkGeothermalFeatures()
	showGeothermalUnits = false
	local geoFeatureDefs = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoFeatureDefs[defID] = true
		end
	end
	spots = {}
	local features = Spring.GetAllFeatures()
	local spotCount = 0
	for i = 1, #features do
		if geoFeatureDefs[Spring.GetFeatureDefID(features[i])] then
			showGeothermalUnits = true
			local x, y, z = Spring.GetFeaturePosition(features[i])
			spotCount = spotCount + 1
			spots[spotCount] = {x, y, z}
		end
	end
end

-- GL4 stuff

-- Notes:
-- 1. Could a prerendered texture be better at conveying metal spot value?
-- 2. VertexVBO contains: x, y pos, rotdir and radians in angle?
-- 3. InstanceVBO contains:
	--x,y,z offsets, radius,
	-- visibility, and gameframe num of the last change teamid of occupier?
-- 4. the way the updates are handled are far from ideal, the construction and destruction of any mex will trigger a full update
--

local spotVBO = nil
local spotInstanceVBO = nil
local spotShader = nil

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance    = InstanceVBOTable.pushElementInstance
local drawInstanceVBO        = InstanceVBOTable.drawInstanceVBO
local getElementInstanceData = InstanceVBOTable.getElementInstanceData


local vsSrc =
[[
#version 420
#line 10000
uniform float timer;

layout (location = 0) in vec4 localpos_dir_angle;
layout (location = 1) in vec4 worldpos_radius;
layout (location = 2) in vec4 visibility; // notoccupied, gameframewhenithappened

out DataVS {
	float circlealpha;
};

//__ENGINEUNIFORMBUFFERDEFS__

void main()
{
	// rotate for animation:
	vec3 vertexWorldPos = vec3(localpos_dir_angle.x,0,localpos_dir_angle.y);
	mat3 roty;
	if (localpos_dir_angle.z < 0 ){
		roty = rotation3dY((timeInfo.x + timeInfo.w)*0.005);
	}else{
		vertexWorldPos.x *= -1; // flip outer circle
		roty = rotation3dY(-(timeInfo.x + timeInfo.w)*0.005);
	}
	vertexWorldPos = roty * vertexWorldPos;

	// scale the circle and move to world pos:
	vertexWorldPos = vertexWorldPos * (12.0 + localpos_dir_angle.z) *2.0* worldpos_radius.w + worldpos_radius.xyz;

	//dump to FS:
	gl_Position = cameraViewProj * vec4(vertexWorldPos,1.0);

	if (visibility.x > 0.5 ){ // going into occupied, so fade out from visibility.y
		circlealpha =  clamp(( (timeInfo.x + timeInfo.w) - visibility.y)/30, 0.0, 0.5);
	}else{ // turned unoccipied, fading into visibility
		circlealpha = clamp(0.5 - ((timeInfo.x + timeInfo.w) - visibility.y)/30, 0.0, 0.5);
	}
	//circlealpha = visibility.x;
}
]]

local fsSrc =
[[
#version 420
#line 20000

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	float circlealpha;
};

out vec4 fragColor;

void main(void)
{
	fragColor = vec4(0.7,1.0,0.7,circlealpha); //debug!
}
]]

local function goodbye(reason)
	Spring.Echo("Geothermalspots GL4 widget exiting with reason: "..reason)
	widgetHandler:RemoveWidget()
end

local function arrayAppend(target, source)
	for _,v in ipairs(source) do
		table.insert(target,v)
	end
end


local function checkGeothermalspots()
	local now = os.clock()
	for i=1, #spots do
		spots[i][2] = spGetGroundHeight(spots[i][1],spots[i][3])
		local spot = spots[i]
		local units = spGetUnitsInSphere(spot[1], spot[2], spot[3], 110*(spot[5] or 1))
		local occupied = false
		local prevOccupied = spots[i][6] or false
		for j=1, #units do
			if extractors[spGetUnitDefID(units[j])] then
				occupied = true
				break
			end
		end
		if occupied ~= prevOccupied then
			spots[i][7] = now
			spots[i][6] = occupied
			local curSpotkey = spotKey(spot[1], spot[3])
			local oldinstance = getElementInstanceData(spotInstanceVBO, curSpotkey)
			oldinstance[5] = (occupied and 0) or 1
			oldinstance[6] = Spring.GetGameFrame()
			pushElementInstance(spotInstanceVBO, oldinstance, curSpotkey, true)
		end
	end
	sceduledCheckedSpotsFrame = Spring.GetGameFrame() + 151
	checkspots = false
end


local function makeSpotVBO()
	spotVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	if spotVBO == nil then goodbye("Failed to create spotVBO") end
	local VBOLayout = {	 {id = 0, name = "localpos_dir_angle", size = 4},}
	local VBOData = {}

	local detailPartWidth, a1,a2,a3,a4
	local width = circleSpaceUsage
	local pieces = 3
	local detail = 13	-- per piece
	local radstep = (2.0 * math.pi) / pieces
	for _,dir in ipairs({-1,1}) do
		for i = 1, pieces do -- pieces
			for d = 1, detail do -- detail
				detailPartWidth = ((width / detail) * d) + (dir+1)
				a1 = ((i+detailPartWidth - (width / detail)) * radstep)
				a2 = ((i+detailPartWidth) * radstep) - ((width / detail)*1.2)
				a3 = ((i+circleInnerOffset+detailPartWidth - (width / detail)) * radstep) - ((width / detail)*0.6)
				a4 = ((i+circleInnerOffset+detailPartWidth) * radstep) - ((width / detail)*0.6)


				arrayAppend(VBOData, {math.sin(a3)*innersize, math.cos(a3)*innersize, dir, a3})
				if dir == 1 then
					arrayAppend(VBOData, {math.sin(a4)*innersize, math.cos(a4)*innersize, dir, a4})
					arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, a1})
				else
					arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, a1})
					arrayAppend(VBOData, {math.sin(a4)*innersize, math.cos(a4)*innersize, dir, a4})
				end

				if dir == -1 then
					arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, a1})
					arrayAppend(VBOData, {math.sin(a2)*outersize, math.cos(a2)*outersize, dir, a2})
				else
					arrayAppend(VBOData, {math.sin(a2)*outersize, math.cos(a2)*outersize, dir, a2})
					arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, a1})
				end
				arrayAppend(VBOData, {math.sin(a4)*innersize, math.cos(a4)*innersize, dir, a4})
			end
		end
	end

	spotVBO:Define(#VBOData/4, VBOLayout)
	spotVBO:Upload(VBOData)
	return spotVBO, #VBOData/4
end

local function initGL4()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	spotShader =  LuaShader(
		{
			vertex = vsSrc,
			fragment = fsSrc,
		},
		"geoSpotShader GL4"
	)
	shaderCompiled = spotShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile spotShader GL4 ") end
	local spotVBO,numVertices = makeSpotVBO()
	local spotInstanceVBOLayout = {
		{id = 1, name = 'worldpos_radius', size = 4},
		{id = 2, name = 'visibility', size = 4},
	}
	spotInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(spotInstanceVBOLayout, 8, "geoSpotInstanceVBO")
	spotInstanceVBO.numVertices = numVertices
	spotInstanceVBO.vertexVBO = spotVBO
	spotInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(spotInstanceVBO.vertexVBO, spotInstanceVBO.instanceVBO)
	spotInstanceVBO.primitiveType = GL.TRIANGLES
end

function widget:ViewResize()
	local old_vsx, old_vsy = vsx, vsy
	vsx,vsy = Spring.GetViewGeometry()
	if old_vsx ~= vsx or old_vsy ~= vsy then
		widget:Shutdown()
		widget:Initialize()
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if checkGeothermalFeatures then
		checkGeothermalFeatures()
	end

	initGL4()

	WG.geothermalspots = {}
	WG.geothermalspots.setShowValue = function(value)
		showValue = value
	end
	WG.geothermalspots.getShowValue = function()
		return showValue
	end
	WG.geothermalspots.setOpacity = function(value)
		opacity = value
	end
	WG.geothermalspots.getOpacity = function()
		return opacity
	end
	WG.geothermalspots.setMetalViewOnly = function(value)
		metalViewOnly = value
	end
	WG.geothermalspots.getMetalViewOnly = function()
		return metalViewOnly
	end

	local currentClock = os.clock()
	local scale = 1
	for i=1, #spots do
		local spot = spots[i]

		local units = spGetUnitsInSphere(spot[1], spot[2], spot[3], 115*scale)
		local occupied = false
		for j=1, #units do
			if extractors[spGetUnitDefID(units[j])] then
				occupied = true
				break
			end
		end
		local y = spGetGroundHeight(spot[1], spot[3])
		spots[i] = {spot[1], y, spot[3], 1, scale, occupied, currentClock}
		pushElementInstance(spotInstanceVBO, {spot[1], y, spot[3], scale, (occupied and 0) or 1, -1000,0,0}, spotKey(spot[1], spot[3]))
	end
end


function widget:Shutdown()
	WG.geothermalspots = nil
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:PlayerChanged(playerID)
	local prevFullview = fullview
	local prevMyAllyTeamID = myAllyTeamID
	isSpec, fullview = Spring.GetSpectatingState()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	if fullview ~= prevFullview or myAllyTeamID ~= prevMyAllyTeamID then
		checkGeothermalspots()
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if extractors[unitDefID] then
		checkspots = true
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if extractors[unitDefID] then
		sceduledCheckedSpotsFrame = Spring.GetGameFrame() + 3	-- delay needed, i don't know why
	end
end

function widget:GameFrame(gf)
	if checkGeothermalFeatures then
		checkGeothermalFeatures()
		checkGeothermalFeatures = nil

		if not showGeothermalUnits then
			widgetHandler:RemoveWidget()
		end
	elseif checkspots or gf >= sceduledCheckedSpotsFrame then
		checkGeothermalspots()
	end
end


function widget:DrawWorldPreUnit()
	local mapDrawMode = spGetMapDrawMode()
	if metalViewOnly and mapDrawMode ~= 'metal' then return end
	if chobbyInterface then return end
	if spIsGUIHidden() then return end

	local clockDifference = (os.clock() - previousOsClock)
	previousOsClock = os.clock()

	gl.DepthTest(false)

	spotShader:Activate()
	drawInstanceVBO(spotInstanceVBO)
	spotShader:Deactivate()

    gl.DepthTest(true)
    gl.Color(1,1,1,1)
end

function widget:GetConfigData(data)
	return {
		showValue = showValue,
		opacity = opacity,
		metalViewOnly = metalViewOnly
	}
end

function widget:SetConfigData(data)
	if data.showValue ~= nil then
		showValue = data.showValue
	end
	if data.opacity ~= nil then
		opacity = data.opacity
	end
	if data.metalViewOnly ~= nil then
		metalViewOnly = data.metalViewOnly
	end
end
