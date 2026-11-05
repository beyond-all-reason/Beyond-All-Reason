local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Geothermalspots",
		desc = "Displays rotating circles around geothermal spots",
		author = "Floris, Beherith GL4",
		date = "August 2021",
		license = "GNU GPL v2",
		layer = 2,
		enabled = true,
	}
end

-- Localized functions for performance
local mathMax = math.max
local mathSin = math.sin
local mathCos = math.cos

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetSpectatingState = Spring.GetSpectatingState

local showValue = false
local metalViewOnly = false

local circleSpaceUsage = 0.82
local circleInnerOffset = 0
local opacity = 0.5

local innersize = 3.0 -- outersize-innersize = circle width
local outersize = 3.32 -- outersize-innersize = circle width

local occupiedRadius = 110 -- a geothermal extractor within this range occupies the spot
local pollFrames = 151 -- every spot is re-checked this often (enemy extractors fire no callins)
local fadeFrames = 16 -- a ring fades in or out over 15 frames in the shader

local spIsGUIHidden = Spring.IsGUIHidden
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMapDrawMode = Spring.GetMapDrawMode

local spots = {} -- {x, y, z, occupied, instanceID}
local numSpots = 0
local numFree = 0 -- spots whose ring is shown
local fadedFrame = 0 -- from this frame on, every ring of an occupied spot has faded out
local checkspots = true
local sceduledCheckedSpotsFrame = spGetGameFrame()

local isSpec, fullview = spGetSpectatingState()
local myAllyTeamID = Spring.GetLocalAllyTeamID()

local chobbyInterface

-- Numeric key avoids tostring + concat per lookup
local function spotKey(x, z)
	return x * 65536 + z
end

local extractors = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.needGeo then
		extractors[uDefID] = true
	end
end

-- Precompute geothermal feature defs once (they never change)
local geoFeatureDefs = {}
for defID, def in pairs(FeatureDefs) do
	if def.geoThermal then
		geoFeatureDefs[defID] = true
	end
end

local spGetAllFeatures = Spring.GetAllFeatures
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition

local function checkGeothermalFeatures()
	spots = {}
	local features = spGetAllFeatures()
	local spotCount = 0
	local seen = {}
	for i = 1, #features do
		if geoFeatureDefs[spGetFeatureDefID(features[i])] then
			local x, y, z = spGetFeaturePosition(features[i])
			-- some maps place each vent twice (SMF and LuaGaia featureplacer, e.g. Delta Siege Dry)
			local key = spotKey(x, z)
			if not seen[key] then
				seen[key] = true
				spotCount = spotCount + 1
				spots[spotCount] = { x = x, y = y, z = z, occupied = false, instanceID = key }
			end
		end
	end
	numSpots = spotCount
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

local spotVBO, spotIndexVBO ---@type VBO?, VBO?
---@type InstanceVBOTable?
local spotInstanceVBO = nil
local spotShader = nil

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local drawInstanceVBO = InstanceVBOTable.drawInstanceVBO
local uploadElementRange = InstanceVBOTable.uploadElementRange

local vsSrc = [[
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
	float frame = timeInfo.x + timeInfo.w;
	if (visibility.x > 0.5 ){ // turned unoccupied, fading into visibility from visibility.y
		circlealpha = clamp((frame - visibility.y) / 30.0, 0.0, 0.5);
	}else{ // going into occupied, so fade out from visibility.y
		circlealpha = clamp(0.5 - (frame - visibility.y) / 30.0, 0.0, 0.5);
	}
	// a faded out ring blends to nothing, so collapse it instead of rasterizing it
	if (circlealpha <= 0.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	// rotate for animation:
	vec3 vertexWorldPos = vec3(localpos_dir_angle.x,0,localpos_dir_angle.y);
	mat3 roty;
	if (localpos_dir_angle.z < 0 ){
		roty = rotation3dY(frame*0.005);
	}else{
		vertexWorldPos.x *= -1; // flip outer circle
		roty = rotation3dY(-frame*0.005);
	}
	vertexWorldPos = roty * vertexWorldPos;

	// scale the circle and move to world pos:
	vertexWorldPos = vertexWorldPos * (12.0 + localpos_dir_angle.z) *2.0* worldpos_radius.w + worldpos_radius.xyz;
	vertexWorldPos.y += 2.0;

	//dump to FS:
	gl_Position = cameraViewProj * vec4(vertexWorldPos,1.0);
}
]]

local fsSrc = [[
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
	Spring.Echo("Geothermalspots GL4 widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function makeSpotVBO()
	spotVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	spotIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if spotVBO == nil or spotIndexVBO == nil then
		goodbye("Failed to create spotVBO")
		return nil
	end
	local VBOLayout = { { id = 0, name = "localpos_dir_angle", size = 4 } }
	local VBOData = {}
	local indices = {}
	local n = 0 -- flat array write index
	local numVertices = 0
	local numIndices = 0

	local function addVertex(angle, size, dir)
		VBOData[n + 1] = mathSin(angle) * size
		VBOData[n + 2] = mathCos(angle) * size
		VBOData[n + 3] = dir
		VBOData[n + 4] = angle
		n = n + 4
		numVertices = numVertices + 1
	end
	local function addTriangle(a, b, c)
		indices[numIndices + 1] = a
		indices[numIndices + 2] = b
		indices[numIndices + 3] = c
		numIndices = numIndices + 3
	end

	local width = circleSpaceUsage
	local pieces = 3
	local detail = 13 -- per piece
	local radstep = (2.0 * math.pi) / pieces
	local widthPerDetail = width / detail
	for _, dir in ipairs({ -1, 1 }) do
		local dirOffset = dir + 1
		for i = 1, pieces do -- pieces
			-- the inner arc is continuous: vertex k at firstInner + k, shared by segments k and k + 1
			local firstInner = numVertices
			for k = 0, detail do
				local detailPartWidth = (widthPerDetail * k) + dirOffset
				local angle = ((i + circleInnerOffset + detailPartWidth) * radstep) - (widthPerDetail * 0.6)
				addVertex(angle, innersize, dir)
			end
			-- the outer arc has a notch between segments, so each segment gets its own two vertices
			for d = 1, detail do -- detail
				local detailPartWidth = (widthPerDetail * d) + dirOffset
				local outer = numVertices
				addVertex(((i + detailPartWidth - widthPerDetail) * radstep), outersize, dir)
				addVertex(((i + detailPartWidth) * radstep) - (widthPerDetail * 1.2), outersize, dir)
				local innerPrev, innerCur = firstInner + d - 1, firstInner + d
				-- dir mirrors the ring in the shader, so the winding flips with it
				if dir == 1 then
					addTriangle(innerPrev, innerCur, outer)
					addTriangle(outer + 1, outer, innerCur)
				else
					addTriangle(innerPrev, outer, innerCur)
					addTriangle(outer, outer + 1, innerCur)
				end
			end
		end
	end

	spotVBO:Define(numVertices, VBOLayout)
	spotVBO:Upload(VBOData)
	spotIndexVBO:Define(numIndices)
	spotIndexVBO:Upload(indices)
	return spotVBO, spotIndexVBO, numIndices
end

local function cleanupGL4(keepShader)
	if spotShader and not keepShader then
		spotShader:Finalize()
		spotShader = nil
	end
	if spotInstanceVBO then
		if spotInstanceVBO.VAO then
			spotInstanceVBO.VAO:Delete()
		end
		if spotInstanceVBO.instanceVBO then
			spotInstanceVBO.instanceVBO:Delete()
		end
		spotInstanceVBO = nil
	end
	if spotVBO then
		spotVBO:Delete()
		spotVBO = nil
	end
	if spotIndexVBO then
		spotIndexVBO:Delete()
		spotIndexVBO = nil
	end
end

local function initGL4()
	cleanupGL4(true) -- a spot rebuild only needs new buffers, the shader does not depend on the spots
	if not spotShader then
		local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
		vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		spotShader = LuaShader({
			vertex = vsSrc,
			fragment = fsSrc,
		}, "geoSpotShader GL4")
		if not spotShader:Initialize() then
			goodbye("Failed to compile spotShader GL4 ")
		end
	end
	local vertexVBO, indexVBO, numIndices = makeSpotVBO()
	if not (vertexVBO and numIndices) then
		return
	end
	local spotInstanceVBOLayout = {
		{ id = 1, name = "worldpos_radius", size = 4 },
		{ id = 2, name = "visibility", size = 4 },
	}
	-- room for every spot, so it never resizes
	spotInstanceVBO =
		InstanceVBOTable.makeInstanceVBOTable(spotInstanceVBOLayout, mathMax(8, numSpots + 2), "geoSpotInstanceVBO")
	spotInstanceVBO.numVertices = numIndices -- drawn with DrawElements, so this is the index count
	spotInstanceVBO.vertexVBO = vertexVBO
	spotInstanceVBO.indexVBO = indexVBO
	-- all three buffers attached, so the engine keeps the VAO instead of rebuilding it every draw
	spotInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(vertexVBO, spotInstanceVBO.instanceVBO, indexVBO)
	spotInstanceVBO.primitiveType = GL.TRIANGLES
end

-- Returns whether a visible geothermal extractor is on the spot
local function isSpotOccupied(spot)
	local units = spGetUnitsInSphere(spot.x, spot.y, spot.z, occupiedRadius)
	for j = 1, #units do
		if extractors[spGetUnitDefID(units[j])] then
			return true
		end
	end
	return false
end

-- Uploads the spot's height, and its occupancy if it flipped at flipFrame
local function updateSpotInstance(spot, flipFrame)
	local instanceTable = spotInstanceVBO
	---@cast instanceTable -?
	local index = instanceTable.instanceIDtoIndex[spot.instanceID] ---@type integer?
	if index then
		local offset = (index - 1) * instanceTable.instanceStep
		local instanceData = instanceTable.instanceData
		instanceData[offset + 2] = spot.y
		if flipFrame then
			instanceData[offset + 5] = spot.occupied and 0 or 1
			instanceData[offset + 6] = flipFrame
		end
		uploadElementRange(instanceTable, index - 1, index)
	end
end

local function checkGeothermalspots()
	local gf = spGetGameFrame()
	for i = 1, numSpots do
		local spot = spots[i]
		local occupied = isSpotOccupied(spot)
		if occupied ~= spot.occupied then
			spot.occupied = occupied
			numFree = numFree + (occupied and -1 or 1)
			fadedFrame = gf + fadeFrames
			updateSpotInstance(spot, gf)
		end
	end
	sceduledCheckedSpotsFrame = gf + pollFrames
	checkspots = false
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	checkGeothermalFeatures()
	if numSpots == 0 then
		widgetHandler:RemoveWidget()
		return
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

	if not spotInstanceVBO then
		return
	end
	numFree = 0
	fadedFrame = 0
	for i = 1, numSpots do
		local spot = spots[i]
		spot.y = spGetGroundHeight(spot.x, spot.z)
		spot.occupied = isSpotOccupied(spot)
		if not spot.occupied then
			numFree = numFree + 1
		end
		pushElementInstance(
			spotInstanceVBO,
			{ spot.x, spot.y, spot.z, 1, spot.occupied and 0 or 1, -1000, 0, 0 },
			spot.instanceID,
			nil,
			true -- noUpload
		)
	end
	InstanceVBOTable.uploadAllElements(spotInstanceVBO)
end

function widget:Shutdown()
	cleanupGL4()
	WG.geothermalspots = nil
end

function widget:RecvLuaMsg(msg, playerID)
	if string.find(msg, "LobbyOverlayActive", 1, true) == 1 then
		chobbyInterface = (string.byte(msg, 19) == 49) -- '1'
	end
end

function widget:PlayerChanged(playerID)
	local prevFullview = fullview
	local prevMyAllyTeamID = myAllyTeamID
	isSpec, fullview = spGetSpectatingState()
	myAllyTeamID = Spring.GetLocalAllyTeamID()
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
		sceduledCheckedSpotsFrame = spGetGameFrame() + 3 -- delay needed, i don't know why
	end
end

-- keeps the spot heights current, so rings follow craters and terraforming right away
function widget:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	-- heightmap squares to elmos, one square wider for the interpolated ground height
	x1, z1, x2, z2 = x1 * 8 - 8, z1 * 8 - 8, x2 * 8 + 8, z2 * 8 + 8
	for i = 1, numSpots do
		local spot = spots[i]
		local x, z = spot.x, spot.z
		if x >= x1 and x <= x2 and z >= z1 and z <= z2 then
			local y = spGetGroundHeight(x, z)
			if y ~= spot.y then
				spot.y = y
				updateSpotInstance(spot)
			end
		end
	end
end

-- Geo vents can be placed and removed at runtime (map editor): rebuild the
-- spots list through Initialize. Deferred by a frame because a feature is
-- still alive inside its own FeatureDestroyed callin.
local geoRebuildFrame = nil

function widget:FeatureCreated(featureID, allyTeamID)
	if geoFeatureDefs[spGetFeatureDefID(featureID)] then
		geoRebuildFrame = spGetGameFrame() + 1
	end
end

function widget:FeatureDestroyed(featureID, allyTeamID)
	if geoFeatureDefs[spGetFeatureDefID(featureID)] then
		geoRebuildFrame = spGetGameFrame() + 2
	end
end

function widget:GameFrame(gf)
	if geoRebuildFrame and gf >= geoRebuildFrame then
		geoRebuildFrame = nil
		widget:Initialize()
		return
	end
	if checkspots or gf >= sceduledCheckedSpotsFrame then
		checkGeothermalspots()
	end
end

function widget:DrawWorld()
	-- Draw after water so underwater spots are not distorted by the water shader.
	if numFree == 0 and spGetGameFrame() >= fadedFrame then -- every ring has faded out
		return
	end
	if chobbyInterface then
		return
	end
	if spIsGUIHidden() then
		return
	end
	if metalViewOnly and spGetMapDrawMode() ~= "metal" then
		return
	end

	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
	gl.PolygonOffset(-64, -64)

	spotShader:Activate()
	drawInstanceVBO(spotInstanceVBO)
	spotShader:Deactivate()

	gl.PolygonOffset(false)
	gl.DepthTest(false)
end

function widget:GetConfigData(data)
	return {
		showValue = showValue,
		opacity = opacity,
		metalViewOnly = metalViewOnly,
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
