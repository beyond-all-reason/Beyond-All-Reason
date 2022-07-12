function widget:GetInfo()
	return {
		name    = "Metalspots",
		desc    = "Displays rotating circles around metal spots",
		author  = "Floris, Beherith GL4",
		date    = "October 2019",
		license = "Lua: GPLv2, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer   = 2,
		enabled = true,
	}
end

if Spring.GetModOptions().unit_restrictions_noextractors then
	return
end

if Spring.GetModOptions().scoremode_chess and Spring.GetModOptions().scoremode ~= 'disabled' then
	return
end

local showValue			= false
local metalViewOnly		= false

local circleSpaceUsage	= 0.62
local circleInnerOffset	= 0.28
local opacity			= 0.5

local innersize			= 1.8		-- outersize-innersize = circle width
local outersize			= 1.98		-- outersize-innersize = circle width

local maxValue			= 15		-- ignore spots above this metal value (probably metalmap)
local maxScale			= 4			-- ignore spots above this scale (probably metalmap)

local spIsGUIHidden = Spring.IsGUIHidden
local spIsSphereInView = Spring.IsSphereInView
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMapDrawMode  = Spring.GetMapDrawMode


local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale
local glBillboard = gl.Billboard
local glCallList = gl.CallList
local glPopMatrix = gl.PopMatrix

local spots = {}
local valueList = {}
local previousOsClock = os.clock()
local checkspots = true
local sceduledCheckedSpotsFrame = Spring.GetGameFrame()

local isSpec, fullview = Spring.GetSpectatingState()
local myAllyTeamID = Spring.GetMyAllyTeamID()

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = math.min(2, (0.5 + (vsx*vsy / 5700000)))
local fontfileSize = 80
local fontfileOutlineSize = 22
local fontfileOutlineStrength = 1.15
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local chobbyInterface

local extractors = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.extractsMetal > 0 then
		extractors[uDefID] = true
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

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrc =
[[
#version 420
uniform float timer;
uniform sampler2D heightMap;

layout (location = 0) in vec4 localpos_dir_angle;
layout (location = 1) in vec4 worldpos_radius;
layout (location = 2) in vec4 visibility; // notoccupied, gameframewhenithappened

out DataVS {
	float circlealpha;
};

//__ENGINEUNIFORMBUFFERDEFS__
#line 10090

float heightAtWorldPos(vec2 w){
	vec2 uvhm = vec2(clamp(w.x, 8.0, mapSize.x - 8.0), clamp(w.y, 8.0, mapSize.y - 8.0)) / mapSize.xy;
	return textureLod(heightMap, uvhm, 0.0).x;
}

void main()
{
	// rotate for animation:
	vec3 vertexWorldPos = vec3(localpos_dir_angle.x,0,localpos_dir_angle.y);

	float s = sign(localpos_dir_angle.z);
	mat3 roty = rotation3dY(s * (timeInfo.x + timeInfo.w) * 0.005);
	vertexWorldPos.x *= s;

	vertexWorldPos = roty * vertexWorldPos;

	// scale the circle and move to world pos:
	vec3 worldXYZ = vec3(worldpos_radius.x, heightAtWorldPos(worldpos_radius.xz), worldpos_radius.z);
	vertexWorldPos = vertexWorldPos * (12.0 + localpos_dir_angle.z) * 2.0 * worldpos_radius.w + worldXYZ;

	//dump to FS:
	gl_Position = cameraViewProj * vec4(vertexWorldPos,1.0);

	circlealpha = mix(
		0.5 - ((timeInfo.x + timeInfo.w)- visibility.y) / 30.0, // turned unoccipied, fading into visibility
		      ((timeInfo.x + timeInfo.w) - visibility.y) / 30.0, // going into occupied, so fade out from visibility.y
		step(0.5, visibility.x)            // 1.0 if visibility is > 0.5
	);
	circlealpha = clamp(circlealpha, 0.0, 0.5);
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
	fragColor = vec4(1.0,1.0,1.0,circlealpha); //debug!
}
]]

local function goodbye(reason)
	Spring.Echo("Metalspots GL4 widget exiting with reason: "..reason)
	widgetHandler:RemoveWidget()
end

local function arrayAppend(target, source)
	for _,v in ipairs(source) do
		table.insert(target,v)
	end
end

local function makeSpotVBO()
	spotVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	if spotVBO == nil then goodbye("Failed to create spotVBO") end
	local VBOLayout = {	 {id = 0, name = "localpos_dir_angle", size = 4},}
	local VBOData = {}

	local detailPartWidth, a1,a2,a3,a4
	local width = circleSpaceUsage
	local pieces = 8
	local detail = 6
	local radstep = (2.0 * math.pi) / pieces
	for _,dir in ipairs({-1,1}) do
		for i = 1, pieces do -- pieces
			for d = 1, detail do -- detail
				detailPartWidth = ((width / detail) * d) + (dir+1)
				a1 = ((i+detailPartWidth - (width / detail)) * radstep)
				a2 = ((i+detailPartWidth) * radstep)
				a3 = ((i+circleInnerOffset+detailPartWidth - (width / detail)) * radstep)
				a4 = ((i+circleInnerOffset+detailPartWidth) * radstep)

				arrayAppend(VBOData, {math.sin(a3)*innersize, math.cos(a3)*innersize, dir, a3})
				arrayAppend(VBOData, {math.sin(a4)*innersize, math.cos(a4)*innersize, dir, a4})
				arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, a1})

				arrayAppend(VBOData, {math.sin(a1)*outersize, math.cos(a1)*outersize, dir, a1})
				arrayAppend(VBOData, {math.sin(a2)*outersize, math.cos(a2)*outersize, dir, a2})
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
		"spotShader GL4"
	)
	shaderCompiled = spotShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile spotShader GL4 ") end
	local spotVBO,numVertices = makeSpotVBO()
	local spotInstanceVBOLayout = {
		{id = 1, name = 'worldpos_radius', size = 4},
		{id = 2, name = 'visibility', size = 4},
	}
	spotInstanceVBO = makeInstanceVBOTable(spotInstanceVBOLayout, 8, "spotInstanceVBO")
	spotInstanceVBO.numVertices = numVertices
	spotInstanceVBO.vertexVBO = spotVBO
	spotInstanceVBO.VAO = makeVAOandAttach(spotInstanceVBO.vertexVBO, spotInstanceVBO.instanceVBO)
	spotInstanceVBO.primitiveType = GL.TRIANGLES
end

local function spotKey(posx,posz)
	return tostring(posx).."_"..tostring(posz)
end

local function checkMetalspots()
	local now = os.clock()
	for i=1, #spots do
		spots[i][2] = spGetGroundHeight(spots[i][1], spots[i][3])
		local spot = spots[i]
		local units = spGetUnitsInSphere(spot[1], spot[2], spot[3], 110*spot[5])
		local occupied = false
		local prevOccupied = spots[i][6]
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

function widget:ViewResize()
	local old_vsx, old_vsy = vsx, vsy
	vsx,vsy = Spring.GetViewGeometry()
	local newFontfileScale = math.min(2, (0.5 + (vsx*vsy / 5700000)))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
	end
	if old_vsx ~= vsx or old_vsy ~= vsy then
		widget:Shutdown()
		widget:Initialize()
	end
end

function widget:Initialize()
	if not WG['resource_spot_finder'].metalSpotsList then
		Spring.Echo("<metalspots> This widget requires the 'Metalspot Finder' widget to run.")
		widgetHandler:RemoveWidget()
	end

	initGL4()

	WG.metalspots = {}
	WG.metalspots.setShowValue = function(value)
		showValue = value
	end
	WG.metalspots.getShowValue = function()
		return showValue
	end
	WG.metalspots.setOpacity = function(value)
		opacity = value
	end
	WG.metalspots.getOpacity = function()
		return opacity
	end
	WG.metalspots.setMetalViewOnly = function(value)
		metalViewOnly = value
	end
	WG.metalspots.getMetalViewOnly = function()
		return metalViewOnly
	end

	local currentClock = os.clock()
	local mSpots = WG['resource_spot_finder'].metalSpotsList
	if mSpots then
		local spotsCount = #spots
		for i = 1, #mSpots do
			local spot = mSpots[i]
			local value = string.format("%0.1f",math.round(spot.worth/1000,1))
			if tonumber(value) > 0.001 and tonumber(value) < maxValue then
				local scale = 0.77 + ((math.max(spot.maxX,spot.minX)-(math.min(spot.maxX,spot.minX))) * (math.max(spot.maxZ,spot.minZ)-(math.min(spot.maxZ,spot.minZ)))) / 10000

				if scale < maxScale then
					local units = spGetUnitsInSphere(spot.x, spot.y, spot.z, 115*scale)
					local occupied = false
					for j=1, #units do
						if extractors[spGetUnitDefID(units[j])]  then
							occupied = true
							break
						end
					end
					spotsCount = spotsCount + 1
					spots[spotsCount] = {spot.x, spGetGroundHeight(spot.x, spot.z), spot.z, value, scale, occupied, currentClock}
					pushElementInstance(spotInstanceVBO, {spot.x, 0, spot.z, scale, (occupied and 0) or 1, -1000,0,0}, spotKey(spot.x, spot.z))
					if not valueList[value] then
						valueList[value] = gl.CreateList(function()
							font:Begin()
							font:SetTextColor(1,1,1,1)
							font:SetOutlineColor(0,0,0,0.4)
							font:Print(value, 0, 0, 1.05, "con")
							font:End()
						end)
					end
				end
			end
		end
	end
	if #spots <= 1 then
		goodbye("not enough spots detected")
	end
end


function widget:Shutdown()
	for k,v in pairs(valueList) do
		gl.DeleteList(v)
	end
	WG.metalspots = nil
	spots = {}
	valueList = {}
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
		checkMetalspots()
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if extractors[unitDefID] then
		checkspots = true
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if extractors[unitDefID] then
		sceduledCheckedSpotsFrame = Spring.GetGameFrame() + 3	-- delay needed, i don't know why
	end
end

function widget:GameFrame(gf)
	if checkspots or gf >= sceduledCheckedSpotsFrame then
		checkMetalspots()
	end
end


function widget:DrawWorldPreUnit()
	local mapDrawMode = spGetMapDrawMode()
	if metalViewOnly and mapDrawMode ~= 'metal' then return end
	if chobbyInterface then return end
	if spIsGUIHidden() then return end

	local clockDifference = (os.clock() - previousOsClock)
	previousOsClock = os.clock()

	gl.Texture(0, "$heightmap")
	gl.DepthTest(false)

	spotShader:Activate()
	drawInstanceVBO(spotInstanceVBO)
	spotShader:Deactivate()

	if Spring.GetGameFrame() == 0 then
		checkMetalspots()
	end

	local spot
	local gf = Spring.GetGameFrame()
	if showValue or gf == 0 or mapDrawMode == 'metal' then
		for i = 1, #spots do
			spot = spots[i]
			if spot[7] and spot[5] < 200 and spIsSphereInView(spot[1], spot[2], spot[3], 60) then
				glPushMatrix()
				glTranslate(spot[1], spot[2], spot[3])
				glScale(21*spot[5],21*spot[5],21*spot[5])
				glBillboard()
				glCallList(valueList[spot[4]])
				glPopMatrix()
			end
		end
	end

    gl.DepthTest(true)
    gl.Color(1,1,1,1)
	gl.Texture(0, false)
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
