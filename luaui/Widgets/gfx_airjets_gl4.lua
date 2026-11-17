--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--https://gist.github.com/lhog/77f3fb10fed0c4e054b6c67eb24efeed#file-test_unitshape_instancing-lua-L177-L178

--------------------------------------------OLD AIRJETS---------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Airjets GL4",
		desc = "Thruster effects on air jet exhausts (auto limits and disables when low fps)",
		author = "GoogleFrog, jK, Floris, Beherith",
		date = "2021.05.16",
		license = "GNU GPL v2",
		layer = -1,
		enabled = true,
	}
end

-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spEcho = Spring.Echo
local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
local spGetTeamList = Spring.GetTeamList
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitPaletteIndex = Spring.GetUnitPaletteIndex
local spGetTeamColor = Spring.GetTeamColor
local spGetCustomPaletteColor = Spring.GetCustomPaletteColor

-- TODO:
-- reflections
-- piece matrix
-- enemy units
-- crashy smores?
-- drawflags
-- rotate emit points of specific units
-- do plenty of bursty anims
-- expose as API?

--------------------------------------------------------------------------------
-- 'Speedups'
--------------------------------------------------------------------------------
---

local spGetGameFrame = Spring.GetGameFrame
local spGetUnitPieceMap = Spring.GetUnitPieceMap
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitTeam = Spring.GetUnitTeam
local spIsUnitInLos = Spring.IsUnitInLos
local glBlending = gl.Blending
local glTexture = gl.Texture
local glUniformInt = gl.UniformInt

local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE

local glAlphaTest = gl.AlphaTest
local glDepthTest = gl.DepthTest

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
---
local autoUpdate = false

-- 0 = never teamcolored, 1 = teamcolored only for effectdefs with teamcolored = true, 2 = force teamcolor on all airjets
-- changeable ingame via /set AirjetsTeamColored <0|1|2>
local teamColorMode = Spring.GetConfigInt("AirjetsTeamColored", 1)

local texture1 = "bitmaps/GPL/perlin_noise.jpg" -- noise texture
local texture2 = "luaui/images/jet_atlas.tga" -- R=opacity(shape), G=perlin displacement strength (per jetType)

-- jet2 atlas: 8 columns of 32x64; per-effect overrides below (defaults preserve the old look)
local defaultJetType = 0 -- atlas column (0..7)
local defaultXZVelSizeMult = 0.0 -- XZ velocity -> jet length multiplier (0 = off, keeps old look)
local defaultYVelSizeMult = 1.0 -- Y  velocity -> jet length multiplier (1 = current behaviour)

local effectDefs = require("luaui/configs/airjet_effects")

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

for name, effects in pairs(effectDefs) do
	if UnitDefNames[name] then
		-- make length and width smaller cause will enlarge when in full effect
		for i, effect in pairs(effects) do
			effect.length = mathFloor(effect.length * 0.8)
			effect.width = mathFloor(effect.width * 0.92)
		end

		-- create scavenger variant
		if UnitDefNames[name .. "_scav"] then
			effectDefs[name .. "_scav"] = deepcopy(effects)
			for i, effect in pairs(effects) do
				effectDefs[name .. "_scav"][i].color = { 0.6, 0.12, 0.7 }
			end
		end
	end
end

local defs = {}
for name, effects in pairs(effectDefs) do
	if UnitDefNames[name] then
		for fx, data in pairs(effects) do
			if not effectDefs[name][fx].emitVector then
				effectDefs[name][fx].emitVector = { 0, 0, -1 }
			end
			if not effectDefs[name][fx].jetType then
				effectDefs[name][fx].jetType = defaultJetType
			end
			if not effectDefs[name][fx].xzVelSizeMult then
				effectDefs[name][fx].xzVelSizeMult = defaultXZVelSizeMult
			end
			if not effectDefs[name][fx].yVelSizeMult then
				effectDefs[name][fx].yVelSizeMult = defaultYVelSizeMult
			end
		end
		defs[UnitDefNames[name].id] = effectDefs[name]
	end
end
effectDefs = defs
defs = nil

-- Build list of DefIDs that have jet effects for filtered unit queries
local effectDefIDList = {}
for defID, _ in pairs(effectDefs) do
	effectDefIDList[#effectDefIDList + 1] = defID
end

--------------------------------------------------------------------------------
-- Variables
--------------------------------------------------------------------------------

local unitJetKeys = {} ---@type table<number, string[]> -- unitID -> instance keys of its jets

local spec, fullview = spGetSpectatingState()
local myAllyTeamID = Spring.GetLocalAllyTeamID()

-- GL4 Notes/TODO:
-- xzVelocityUnits is disabled
-- no FPS limited
-- draw in refract/reflect too?
-- GL4 Variables:

---@type InstanceVBOTable?
local jetInstanceVBO = nil
local jetShader = nil
local quadVBO, quadIndexVBO ---@type VBO?, VBO?
local reflectionPassLocation = -1
local lastReflectionPass = false -- matches the shader default

local LuaShader = gl.LuaShader

local drawInstanceVBO = gl.InstanceVBOTable.drawInstanceVBO
local popElementInstance = gl.InstanceVBOTable.popElementInstance
local pushElementInstance = gl.InstanceVBOTable.pushElementInstance
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

local vsSrc = [[#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000
uniform int reflectionPass = 0;

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec3 widthlengthtime; // time is gameframe spawned :D
layout (location = 2) in vec3 emitdir;
layout (location = 3) in vec3 color;
layout (location = 4) in uint pieceIndex;
layout (location = 5) in uvec4 instData; // unitID, teamID, ??
layout (location = 6) in vec3 jetParams; // x: xzVelSizeMult, y: yVelSizeMult, z: jetType (atlas column)

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

out DataVS {
	vec4 texCoords;
	vec4 jetcolor;
	flat float jetAtlas;

	#if (DEBUG == 1)
		vec4 debug0;
		vec4 debug1;
	#endif
};


struct SUniformsBuffer {
    uint composite; //     u8 drawFlag; u8 unused1; u16 id;

    uint unused2;
    uint unused3;
    uint unused4;

    float maxHealth;
    float health;
    float unused5;
    float unused6;

    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
};

#if USEQUATERNIONS == 0
	layout(std140, binding=0) readonly buffer MatrixBuffer {
		mat4 UnitPieces[];
	};
#else
	//__QUATERNIONDEFS__
#endif

#line 10253
void main()
{
	jetcolor.rgb = color;
	jetcolor.a = clamp((timeInfo.x + timeInfo.w - widthlengthtime.z)*0.053, 0.0, 1.0);
	jetAtlas = jetParams.z;

	texCoords.st = position_xy_uv.zw;
	texCoords.pq = position_xy_uv.zw;
	texCoords.q += (timeInfo.x + timeInfo.w) * 0.1;

	#if USEQUATERNIONS == 0
		uint baseIndex = instData.x; // grab the correct offset into UnitPieces SSBO
		mat4 modelMatrix = UnitPieces[baseIndex]; //Find our matrix
		mat4 pieceMatrix = mat4mix(mat4(1.0), UnitPieces[baseIndex + pieceIndex + 1u], modelMatrix[3][3]);
		mat4 worldMat = modelMatrix * pieceMatrix;
	#else
		mat4 worldMat = TransformToMatrix(GetPieceWorldTransform(instData.x, pieceIndex));
	#endif

	vec4 speedvector = uni[instData.y].speed;

	vec2 modulatedsize = widthlengthtime.xy * 1.5;
	modulatedsize.y *= clamp(speedvector.y * 0.5 * jetParams.y + 1.0 , 0.66, 2.0); // Y velocity -> length (wider clamps stretched climbing jets)
	modulatedsize.y *= clamp(length(speedvector.xz) * 0.5 * jetParams.x + 1.0, 0.33, 4.0); // XZ velocity -> length
	// modulatedsize += rndVec3.xy * modulatedsize * 0.25; // not very pretty
	vec2 vertexOffset = position_xy_uv.xy * vec2(modulatedsize.x * 2.0, modulatedsize.y * 0.66); // across, along piece z

	// turn the quad about the jet (piece z) axis to face the camera: its width runs along cross(toCamera, axis)
	vec3 jetAxis = worldMat[2].xyz;
	vec3 worldPos = worldMat[3].xyz + vertexOffset.x * worldMat[0].xyz + vertexOffset.y * jetAxis; // unturned vertex
	vec3 worldCamPos = cameraViewInv[3].xyz;
	vec3 widthAxis = cross(worldCamPos - worldPos, jetAxis);
	widthAxis *= length(worldMat[0].xyz) * inversesqrt(dot(widthAxis, widthAxis));

	mat4 VP = (reflectionPass == 0) ? cameraViewProj : reflectionViewProj;
	gl_Position = VP * vec4(worldMat[3].xyz + vertexOffset.x * widthAxis + vertexOffset.y * jetAxis, 1.0);

	// unit not drawn (drawflag) or jet not faded in: collapse the quad outside the clip volume, no fragments
	if ((uni[instData.y].composite & 0x00000001u) == 0u || jetcolor.a == 0.0) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);

	if (reflectionPass > 0) {  // reflections are drawn 3x brighter, without underwater jets
		jetcolor.a *= 3.0;
		if (worldPos.y < -5.0) jetcolor = vec4(0.0);
	}
	#if (DEBUG == 1)
		debug0 = vec4(worldPos, 1.0);
		debug1 = vec4(worldCamPos, 1.0);
	#endif
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000
uniform sampler2D noiseMap;
uniform sampler2D mask;

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

#define DISTORTION 0.01
#define JET_ATLAS_COLS 8.0 // 256px / 32px per cell
in DataVS {
	vec4 texCoords;
	vec4 jetcolor;
	flat float jetAtlas;
	#if DEBUG == 1
		vec4 debug0;
		vec4 debug1;
	#endif
};

out vec4 fragColor;

void main(void)
{
		vec2 displacement = texCoords.pq;
		vec2 cellUV = texCoords.st;

		// per-cell perlin displacement strength from the GREEN channel (g=1.0 => baseline DISTORTION)
		float distortion = texture(mask, vec2((jetAtlas + cellUV.s) / JET_ATLAS_COLS, cellUV.t)).g * DISTORTION;

		vec2 txCoord = cellUV;
		txCoord.s += (texture(noiseMap, displacement * DISTORTION * 20.0).y - 0.5) * 40.0 * distortion;
		txCoord.t +=  texture(noiseMap, displacement).x * (1.0-cellUV.t)         * 15.0 * distortion;

		vec2 atlasUV = vec2((jetAtlas + clamp(txCoord.s, 0.0, 1.0)) / JET_ATLAS_COLS, txCoord.t);
		float opac = texture(mask, atlasUV).r;
		#if (DEBUG == 0)
			if (opac <= 0.0) discard; // adds nothing
		#endif

		float opac2 = opac * opac;
		fragColor.rgb  = opac * jetcolor.rgb; //color
		fragColor.rgb += opac2 * opac2 * opac; //white flame, pow(opac, 5.0)
		fragColor.a    = opac * 1.5;
		fragColor.rgba = clamp(fragColor, 0.0, 1.0) * jetcolor.a; // jetcolor.a: fade-in, 3x in reflections

		#if (DEBUG == 1)
			fragColor.rgba = max(fragColor.rgba, vec4(0.2));
		#endif

}
]]

local function goodbye(reason)
	spEcho("Airjet GL4 widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local jetShaderSourceCache = {
	vsSrc = vsSrc,
	fsSrc = fsSrc,
	shaderName = "JetShader GL4",
	uniformInt = {
		noiseMap = 0,
		mask = 1,
	},
	uniformFloat = {
		--jetuniforms = {1,1,1,1}, --unused
		--iconDistance = 1,
	},
	shaderConfig = {
		USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
		DEBUG = autoUpdate and "1" or "0",
	},
	forceupdate = true, -- otherwise file-less defines are not updated
}

local function initGL4()
	jetShader = LuaShader.CheckShaderUpdates(jetShaderSourceCache)
	--spEcho(jetShader.shaderParams.vertex)
	if not jetShader then
		goodbye("Failed to compile jetShader GL4 ")
		return false
	end
	reflectionPassLocation = gl.GetUniformLocation(jetShader.shaderObj, "reflectionPass")
	lastReflectionPass = false

	-- one quad, its 4 corners shared by both triangles: x across the jet, y from 0 (nozzle) to -1 (tail), uv
	quadVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	quadIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not quadVBO or not quadIndexVBO then
		goodbye("Failed to create the jet quad VBO")
		return false
	end
	quadVBO:Define(4, { { id = 0, name = "position_xy_uv", size = 4 } })
	quadVBO:Upload({ -1, 0, 0, 1, -1, -1, 0, 0, 1, -1, 1, 0, 1, 0, 1, 1 })
	quadIndexVBO:Define(6)
	quadIndexVBO:Upload({ 0, 1, 2, 2, 3, 0 })

	local jetInstanceVBOLayout = {
		{ id = 1, name = "widthlengthtime", size = 3 }, -- widthlength
		{ id = 2, name = "emitdir", size = 3 }, --  emit dir
		{ id = 3, name = "color", size = 3 }, --- color
		{ id = 4, name = "pieceIndex", type = GL.UNSIGNED_INT, size = 1 },
		{ id = 5, name = "instData", type = GL.UNSIGNED_INT, size = 4 },
		{ id = 6, name = "jetParams", size = 3 }, -- x: xzVelSizeMult, y: yVelSizeMult, z: jetType
	}
	jetInstanceVBO = gl.InstanceVBOTable.makeInstanceVBOTable(jetInstanceVBOLayout, 256, "jetInstanceVBO", 5)
	jetInstanceVBO.numVertices = 6
	jetInstanceVBO.vertexVBO = quadVBO
	jetInstanceVBO.indexVBO = quadIndexVBO
	jetInstanceVBO.VAO = gl.InstanceVBOTable.makeVAOandAttach(quadVBO, jetInstanceVBO.instanceVBO, quadIndexVBO)
	jetInstanceVBO.primitiveType = GL.TRIANGLES
	return true
end

--------------------------------------------------------------------------------
-- Draw Iteration
--------------------------------------------------------------------------------

local function DrawParticles(isReflection)
	if jetInstanceVBO.usedElements > 0 then
		gl.Culling(false)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove both state changes
		glDepthTest(true)

		glAlphaTest(false) -- the shader discards empty fragments itself

		glTexture(0, texture1)
		glTexture(1, texture2)
		glBlending(GL_ONE, GL_ONE)
		jetShader:Activate()

		if isReflection ~= lastReflectionPass then
			lastReflectionPass = isReflection
			glUniformInt(reflectionPassLocation, isReflection and 1 or 0)
		end

		drawInstanceVBO(jetInstanceVBO)

		jetShader:Deactivate()
		glTexture(0, false)
		glTexture(1, false)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		glDepthTest(false)
		--gl.DepthMask(false) --"BK OpenGL state resets", was true but now commented out (redundant set of false states)
	end
end

--------------------------------------------------------------------------------
-- Unit Handling
--------------------------------------------------------------------------------

local function FinishInitialization(unitID, effectDef)
	local pieceMap = spGetUnitPieceMap(unitID)
	for i = 1, #effectDef do
		local fx = effectDef[i]
		if fx.piece then
			--spEcho("FinishInitialization", fx.piece, pieceMap[fx.piece])
			fx.piecenum = pieceMap[fx.piece]
		end
		fx.width = fx.width * 1.2
		fx.length = fx.length * 1.4
	end
	effectDef.finishedInit = true
end

local instanceData = {} -- reused, pushElementInstance copies it

local function Activate(unitID, unitDefID, noUpload)
	--spEcho(Spring.GetGameFrame(), "Activate(unitID, unitDefID)",unitID, unitDefID)
	if spGetUnitIsDead(unitID) == true then
		--Spring.SendCommands({"pause 1"})
		return
	end

	local unitEffects = effectDefs[unitDefID]
	if not unitEffects.finishedInit then
		FinishInitialization(unitID, unitEffects)
	end

	local keys = {}
	local teamR, teamG, teamB
	for i = 1, #unitEffects do
		local effectDef = unitEffects[i]
		local color = effectDef.color
		local r, g, b = color[1], color[2], color[3]
		if teamColorMode == 2 or (teamColorMode == 1 and effectDef.teamcolored) then
			if not teamR then
				local unitCustomPaletteIndex = spGetUnitPaletteIndex(unitID)
				if unitCustomPaletteIndex then
					teamR, teamG, teamB = spGetCustomPaletteColor(unitCustomPaletteIndex)
				else
					teamR, teamG, teamB = spGetTeamColor(spGetUnitTeam(unitID))
				end
			end
			r, g, b = teamR, teamG, teamB
			if effectDef.teamcolorDesaturation then
				r = r + ((1 - r) * effectDef.teamcolorDesaturation)
				g = g + ((1 - g) * effectDef.teamcolorDesaturation)
				b = b + ((1 - b) * effectDef.teamcolorDesaturation)
			end
		end
		local emitVector = effectDef.emitVector
		instanceData[1] = effectDef.width * 0.4
		instanceData[2] = effectDef.length
		instanceData[3] = 0 -- spawn frame, for the fade-in
		instanceData[4] = emitVector[1]
		instanceData[5] = emitVector[2]
		instanceData[6] = emitVector[3]
		instanceData[7] = r
		instanceData[8] = g
		instanceData[9] = b
		instanceData[10] = effectDef.piecenum - 1
		instanceData[11] = 0
		instanceData[12] = 0
		instanceData[13] = 0
		instanceData[14] = 0 -- this is needed to keep the lua copy of the vbo the correct size
		instanceData[15] = effectDef.xzVelSizeMult
		instanceData[16] = effectDef.yVelSizeMult
		instanceData[17] = effectDef.jetType
		local key = unitID .. "_" .. effectDef.piecenum
		keys[i] = key
		pushElementInstance(jetInstanceVBO, instanceData, key, true, noUpload, unitID)
	end
	unitJetKeys[unitID] = keys
end

local function RemoveUnit(unitID)
	local keys = unitJetKeys[unitID]
	if keys then
		unitJetKeys[unitID] = nil
		local instanceIDtoIndex = jetInstanceVBO.instanceIDtoIndex
		for i = 1, #keys do
			if instanceIDtoIndex[keys[i]] then
				popElementInstance(jetInstanceVBO, keys[i])
			end
		end
	end
end

local function reInitialize()
	unitJetKeys = {}
	gl.InstanceVBOTable.clearInstanceTable(jetInstanceVBO)

	for _, teamID in ipairs(spGetTeamList()) do
		local teamUnits = spGetTeamUnitsByDefs(teamID, effectDefIDList)
		if teamUnits then
			for i = 1, #teamUnits do
				local unitID = teamUnits[i]
				local unitDefID = spGetUnitDefID(unitID)
				if effectDefs[unitDefID] then
					Activate(unitID, unitDefID, true)
				end
			end
		end
	end
	uploadAllElements(jetInstanceVBO) -- one upload instead of one per jet
end

--------------------------------------------------------------------------------
-- Widget Interface
--------------------------------------------------------------------------------

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if fullview then
		return
	end
	unitDefID = unitDefID or spGetUnitDefID(unitID)
	if effectDefs[unitDefID] then
		--spEcho("UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)",unitID, unitTeam, allyTeam, unitDefID)
		Activate(unitID, unitDefID)
	end
end

function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if not fullview then
		--spEcho("UnitLeftLos(unitID, unitDefID, unitTeam)",unitID, unitTeam, allyTeam, unitDefID)
		RemoveUnit(unitID)
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	--spEcho("UnitCreated(unitID, unitDefID, unitTeam)",unitID, unitDefID, unitTeam)
	if effectDefs[unitDefID] then
		Activate(unitID, unitDefID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	--spEcho("UnitDestroyed(unitID, unitDefID, unitTeam)",unitID, unitDefID, unitTeam)
	RemoveUnit(unitID)
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	RemoveUnit(unitID)
end

function widget:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	--spEcho("RenderUnitDestroyed(unitID, unitDefID, unitTeam)",unitID, unitDefID, unitTeam)
	RemoveUnit(unitID)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	if effectDefs[unitDefID] and spIsUnitInLos(unitID) then
		Activate(unitID, unitDefID)
	end
end
function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeamId)
	if unitJetKeys[unitID] and spIsUnitInLos(unitID) then
		RemoveUnit(unitID)
	end
end

local configCheckFrame = 0
function widget:DrawWorld()
	-- polled here instead of in an Update callin
	configCheckFrame = configCheckFrame + 1
	if configCheckFrame >= 30 then
		configCheckFrame = 0
		local newTeamColorMode = Spring.GetConfigInt("AirjetsTeamColored", 1)
		if newTeamColorMode ~= teamColorMode then
			teamColorMode = newTeamColorMode
			reInitialize()
		end
	end
	DrawParticles(false)
end

function widget:DrawWorldReflection()
	DrawParticles(true)
end

function widget:PlayerChanged(playerID)
	local currentspec, currentfullview = spGetSpectatingState()
	local currentAllyTeamID = Spring.GetLocalAllyTeamID()
	local reinit = false
	if
		(currentspec ~= spec)
		or (currentfullview ~= fullview)
		or ((currentAllyTeamID ~= myAllyTeamID) and not currentfullview) -- our ALLYteam changes, and we are not in fullview
	then
		-- do the actual reinit stuff:
		--spEcho("Airjets reinit")
		reinit = true
	end

	spec = currentspec
	fullview = currentfullview
	myAllyTeamID = currentAllyTeamID
	if reinit then
		reInitialize()
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not initGL4() then
		return
	end
	reInitialize()

	WG.airjets = {}

	WG.airjets.addAirJet = function(
		unitID,
		piecenum,
		width,
		length,
		color3,
		emitVector,
		xzVelSizeMult,
		yVelSizeMult,
		jetType
	) -- for WG external calls
		local airjetkey = tostring(unitID) .. "_" .. tostring(piecenum)
		if emitVector == nil then
			emitVector = { 0, 0, -1 }
		end
		pushElementInstance(
			jetInstanceVBO,
			{
				width * 5,
				length * 5,
				spGetGameFrame(),
				emitVector[1],
				emitVector[2],
				emitVector[3],
				color3[1],
				color3[2],
				color3[3],
				piecenum,
				0,
				0,
				0,
				0, -- this is needed to keep the lua copy of the vbo the correct size
				xzVelSizeMult or defaultXZVelSizeMult,
				yVelSizeMult or defaultYVelSizeMult,
				jetType or defaultJetType,
			},
			airjetkey,
			true, -- update existing
			nil, -- noupload
			unitID -- unitID
		)
		return airjetkey
	end

	WG.airjets.removeAirJet = function(airjetkey) ---- for WG external calls
		return popElementInstance(jetInstanceVBO, airjetkey)
	end
end

if autoUpdate then
	function widget:DrawScreen()
		--spEcho("drawprintf", jetShader.DrawPrintf, jetShader.printf)
		if jetShader.DrawPrintf then
			jetShader.DrawPrintf()
		end
	end
end

function widget:Shutdown()
	if jetInstanceVBO then
		jetInstanceVBO:Delete() -- instance VBO and VAO
		jetInstanceVBO = nil
	end
	if quadVBO then
		quadVBO:Delete()
	end
	if quadIndexVBO then
		quadIndexVBO:Delete()
	end
	if jetShader then
		jetShader:Finalize()
		jetShader = nil
	end
	WG.airjets = nil
end
