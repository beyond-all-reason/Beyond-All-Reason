local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Paralyze Effect",
		version = "v0.2",
		desc = "Faster gl.UnitShape, Use WG.UnitShapeGL4",
		author = "Beherith",
		date = "2021.11.04",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetUnitHealth = Spring.GetUnitHealth
local spEcho = Spring.Echo
local spGetAllUnits = Spring.GetAllUnits
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local glSetUnitBufferUniforms = gl.SetUnitBufferUniforms

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOIdTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

-- Octaves of 4D simplex noise per fragment of a paralyzed unit. 4 is the original look; 3 drops a
-- quarter of the fragment cost and loses the finest flicker detail.
local paralyzeNoiseOctaves = 4

-- for testing: /luarules benchmark corak armpw 100 10 3000

local paralyzedUnitShader, unitShapeShader

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10000
//__DEFINES__

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 T;
layout (location = 3) in vec3 B;
layout (location = 4) in vec4 uv;

layout (location = 5) in uvec2 bonesInfo; //boneIDs, boneWeights
#define pieceIndex (bonesInfo.x & 0x000000FFu)

layout (location = 6) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__

layout(std140, binding = 2) uniform FixedStateMatrices {
	mat4 modelViewMat;
	mat4 projectionMat;
	mat4 textureMat;
	mat4 modelViewProjectionMat;
};
#line 15000

#if USEQUATERNIONS == 0
	layout(std140, binding=0) buffer MatrixBuffer {
		mat4 mat[];
	};
#else
	//__QUATERNIONDEFS__
#endif



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

out vec3 v_modelPosOrig;
flat out float v_paralysis;

void main() {
	uint baseIndex = instData.x;

	#line 16000
	#if USEQUATERNIONS == 0
		mat4 modelMatrix = mat[baseIndex];

		uint isDynamic = 1u; //default dynamic model
		// dynamic models have one extra matrix, as their first matrix is their world pos/offset
		//mat4 pieceMatrix = mat4mix(mat4(1.0), mat[baseIndex + pieceIndex + isDynamic ], modelMatrix[3][3]);
		mat4 pieceMatrix = mat4mix(mat4(1.0), mat[baseIndex + pieceIndex + isDynamic ], 1.0);
		vec4 localModelPos = pieceMatrix * vec4(pos, 1.0);

		v_modelPosOrig = localModelPos.xyz + (modelMatrix[3].xyz)*0.3;
		vec4 modelPos = modelMatrix * localModelPos;

	#else
		Transform pieceModelTransform = GetPieceModelTransform(baseIndex, pieceIndex);
		Transform modelWorldTransform = GetModelWorldTransform(baseIndex);

		v_modelPosOrig = (ApplyTransform(pieceModelTransform, vec4(pos, 1.0))).xyz;

		vec4 modelPos = ApplyTransform(modelWorldTransform, vec4(v_modelPosOrig.xyz, 1.0));
	#endif

	float paralyzestrength = uni[instData.y].userDefined[1].x; // this (paralyzedamage/maxhealth), so >=1.0 is paralyzed
	v_paralysis = min(paralyzestrength * paralyzestrength, 1.1);

	gl_Position = cameraViewProj * modelPos;
	// drawFlag 1 or 2 means drawn as a full model (not an icon) this frame; otherwise the effect is alpha 0, so cull it
	if ((uni[instData.y].composite & 0x00000003u) == 0u || v_paralysis == 0.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
	}
}
]]

local fsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

// 4D NOISE:
//	Simplex 4D Noise
//	by Ian McEwan, Ashima Arts
//
// The hashing and gradients below are reduced but return exactly the values of the original.
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec2 permute(vec2 x){return mod(((x*34.0)+1.0)*x, 289.0);}
float permute(float x){return mod(((x*34.0)+1.0)*x, 289.0);} // whole numbers in and out, so no floor
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
float taylorInvSqrt(float r){return 1.79284291400159 - 0.85373472095314 * r;}

vec4 grad4(float j, vec4 ip){
  const vec4 ones = vec4(1.0, 1.0, 1.0, -1.0);
  vec4 p;

  p.xyz = floor( fract (vec3(j) * ip.xyz) * 7.0) * ip.z - 1.0;
  p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
  p.xyz += float(p.w < 0.0); // p.xyz is always negative here, so this is the whole sign fix-up

  return p;
}

float snoise(vec4 v){
  const vec2  C = vec2( 0.138196601125010504,  // (5 - sqrt(5))/20  G4
                        0.309016994374947451); // (sqrt(5) - 1)/4   F4
// First corner
  vec4 i  = floor(v + dot(v, C.yyyy) );
  vec4 x0 = v -   i + dot(i, C.xxxx);

// Other corners

// Rank sorting originally contributed by Bill Licea-Kane, AMD (formerly ATI)
  vec4 i0;

  vec3 isX = step( x0.yzw, x0.xxx );
  vec3 isYZ = step( x0.zww, x0.yyz );
//  i0.x = dot( isX, vec3( 1.0 ) );
  i0.x = isX.x + isX.y + isX.z;
  i0.yzw = 1.0 - isX;

//  i0.y += dot( isYZ.xy, vec2( 1.0 ) );
  i0.y += isYZ.x + isYZ.y;
  i0.zw += 1.0 - isYZ.xy;

  i0.z += isYZ.z;
  i0.w += 1.0 - isYZ.z;

  // i0 now contains the unique values 0,1,2,3 in each channel
  vec4 i3 = clamp( i0, 0.0, 1.0 );
  vec4 i2 = clamp( i0-1.0, 0.0, 1.0 );
  vec4 i1 = clamp( i0-2.0, 0.0, 1.0 );

  //  x0 = x0 - 0.0 + 0.0 * C
  vec4 x1 = x0 - i1 + 1.0 * C.xxxx;
  vec4 x2 = x0 - i2 + 2.0 * C.xxxx;
  vec4 x3 = x0 - i3 + 3.0 * C.xxxx;
  vec4 x4 = x0 - 1.0 + 4.0 * C.xxxx;

// Permutations
  i = mod(i, 289.0);
  // the first level only ever hashes i.w or i.w + 1, so do those two once and pick per corner
  vec2 jw = permute(i.ww + vec2(0.0, 1.0));
  float j0 = permute( permute( permute( jw.x + i.z) + i.y) + i.x);
  vec4 j1 = permute( permute( permute(
             jw.x + vec4(i1.w, i2.w, i3.w, 1.0 ) * (jw.y - jw.x)
           + i.z + vec4(i1.z, i2.z, i3.z, 1.0 ))
           + i.y + vec4(i1.y, i2.y, i3.y, 1.0 ))
           + i.x + vec4(i1.x, i2.x, i3.x, 1.0 ));
// Gradients
// ( 7*7*6 points uniformly over a cube, mapped onto a 4-octahedron.)
// 7*7*6 = 294, which is close to the ring size 17*17 = 289.

  vec4 ip = vec4(1.0/294.0, 1.0/49.0, 1.0/7.0, 0.0) ;

  vec4 p0 = grad4(j0,   ip);
  vec4 p1 = grad4(j1.x, ip);
  vec4 p2 = grad4(j1.y, ip);
  vec4 p3 = grad4(j1.z, ip);
  vec4 p4 = grad4(j1.w, ip);

// Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;
  p4 *= taylorInvSqrt(dot(p4,p4));

// Mix contributions from the five corners
  vec3 m0 = max(0.6 - vec3(dot(x0,x0), dot(x1,x1), dot(x2,x2)), 0.0);
  vec2 m1 = max(0.6 - vec2(dot(x3,x3), dot(x4,x4)            ), 0.0);
  m0 = m0 * m0;
  m1 = m1 * m1;
  return 49.0 * ( dot(m0*m0, vec3( dot( p0, x0 ), dot( p1, x1 ), dot( p2, x2 )))
               + dot(m1*m1, vec2( dot( p3, x3 ), dot( p4, x4 ) ) ) ) ;

}

//END 4D NOISE


//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec3 v_modelPosOrig;
flat in float v_paralysis;

out vec4 fragColor;
#line 25000
void main() {
	float paralysis_level = v_paralysis; // values of 1 are fully paralyzed

	float noisescale;
	float persistence;
	float lacunarity;
	vec3 minlightningcolor;
	vec3 maxlightningcolor;
	vec4 wholeunitbasecolor;
	float lightningalpha;
	float lighting_sharpness;
	float lighting_width;
	float lightning_speed;

	// ------------------ CONFIG START --------------------

	if (paralysis_level < 0.9999) { // not fully paralyzed
		noisescale = 0.15;
		persistence = 0.45;
		lacunarity = 2.5;
		minlightningcolor = vec3(0.1, 0.1, 0.5); //blue
		maxlightningcolor = vec3(0.9, 0.9, 0.9); //white
		wholeunitbasecolor = vec4(0.0, 0.0, 0.0, 0.0); // none
		lightningalpha = 1.4;
		lighting_sharpness = 12.8;
		lighting_width = 3.95;
		lightning_speed = 0.14;
	}
	else{ // fully paralyzed
		noisescale = 0.31;
		persistence = 0.45;
		lacunarity = 2.5;
		minlightningcolor = vec3(0.1, 0.1, 1.0); //blue
		maxlightningcolor = vec3(1.0, 1.0, 1.0); //white
		wholeunitbasecolor = vec4(0.49, 0.43, 0.94, 0.35); // light blue base tone
		lightningalpha = 1.2;
		lighting_sharpness = 4.8;
		lighting_width = 3.8;
		lightning_speed = 0.95;
	}
	// ------------------ CONFIG END --------------------

	vec4 noiseposition = noisescale * vec4(v_modelPosOrig, (timeInfo.x + timeInfo.w) * lightning_speed);
	float noise4 = 0;
	for (int i = 1; i <= PARALYZE_NOISE_OCTAVES; ++i) {
		noise4 += pow(persistence, float(i)) * snoise(noiseposition * 0.025 * pow(lacunarity, float(i)));
	}
	noise4 = (1.0 * noise4 + 0.5);
	float electricity = clamp(1.0 - abs(noise4 - 0.5) * lighting_width, 0.0, 1.0);
	electricity = clamp(pow(electricity, lighting_sharpness), 0.0, 1.0);

	vec3 lightningcolor;
	float effectalpha;
	if (paralysis_level < 0.9999) {
		#if EMPREWORK == 1
			paralysis_level = min(paralysis_level * 3.0, 1.0);
			if (paralysis_level > 0.49) { wholeunitbasecolor = vec4(0.35, 0.43, 0.94, 0.18); }
		#endif
		// Calculate the lightning color based on the amount of electricity
		lightningcolor = mix(minlightningcolor, maxlightningcolor, electricity);
		effectalpha = paralysis_level * lightningalpha; // less transparency non-paralyzed
	}
	else
	{
		lightningcolor = mix(minlightningcolor, maxlightningcolor, electricity);
		effectalpha = clamp(paralysis_level * lightningalpha, 0.0, 1.0);
	}

	fragColor = vec4(lightningcolor, electricity*effectalpha);
	fragColor = max(wholeunitbasecolor, fragColor); // apply whole unit base color
}
]]

local paralyzeSourceShaderCache = {
	vsSrc = vsSrc,
	fsSrc = fsSrc,
	shaderName = "paralyzedUnitShader",
	uniformInt = {},
	uniformFloat = {},
	shaderConfig = {
		USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
		PARALYZE_NOISE_OCTAVES = tostring(math.max(1, math.floor(paralyzeNoiseOctaves))),
		EMPREWORK = Spring.GetModOptions().emprework and "1" or "0",
	},
	forceupdate = true, -- otherwise file-less defines are not updated
}

---@type InstanceVBOTable?
local paralyzedDrawUnitVBOTable

-- the only instance attribute is instData, which InstanceDataFromUnitIDs fills in
local instanceCache = { 0, 0, 0, 0 }

local function initGL4()
	local vertVBO = gl.GetVBO(GL.ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	local indxVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	vertVBO:ModelsVBO()
	indxVBO:ModelsVBO()

	local VBOLayout = {
		{ id = 6, name = "instData", type = GL.UNSIGNED_INT, size = 4 },
	}

	local maxElements = 32 -- start small for testing
	local unitIDAttributeIndex = 6
	paralyzedDrawUnitVBOTable = InstanceVBOTable.makeInstanceVBOTable(
		VBOLayout,
		maxElements,
		"paralyzedDrawUnitVBOTable",
		unitIDAttributeIndex,
		"unitID"
	)

	paralyzedDrawUnitVBOTable.VAO =
		InstanceVBOTable.makeVAOandAttach(vertVBO, paralyzedDrawUnitVBOTable.instanceVBO, indxVBO)
	paralyzedDrawUnitVBOTable.indexVBO = indxVBO
	paralyzedDrawUnitVBOTable.vertexVBO = vertVBO

	paralyzedUnitShader = LuaShader.CheckShaderUpdates(paralyzeSourceShaderCache)

	if not paralyzedUnitShader then
		spEcho("paralyzedUnitShaderCompiled shader compilation failed", paralyzedUnitShader)
		widgetHandler:RemoveWidget()
	end
end

-- unitID -> paralyzeDamage / maxHealth last written to the unit's uniforms
local paralyzeStrength = {}
local uniformcache = { 0 }

local function SetParalyzeStrength(unitID, strength)
	if strength ~= paralyzeStrength[unitID] then
		paralyzeStrength[unitID] = strength
		uniformcache[1] = strength
		glSetUnitBufferUniforms(unitID, uniformcache, 4)
	end
end

local function DrawParalyzedUnitGL4(unitID)
	-- Documentation for DrawParalyzedUnitGL4:
	--	unitID: the actual unitID that you want to draw
	-- returns: a unique handler ID number that you should store and call StopDrawParalyzedUnitGL4(uniqueID) with to stop drawing it
	-- note that widgets are responsible for stopping the drawing of every unit that they submit!

	--spEcho("DrawParalyzedUnitGL4",unitID)
	if paralyzedDrawUnitVBOTable.instanceIDtoIndex[unitID] then
		return
	end -- already got this unit
	if spValidUnitID(unitID) ~= true or spGetUnitIsDead(unitID) == true then
		return
	end

	pushElementInstance(paralyzedDrawUnitVBOTable, instanceCache, unitID, true, nil, unitID, "unitID")
	--spEcho("Pushed",  unitID, elementID)
	return unitID
end

local function StopDrawParalyzedUnitGL4(unitID)
	if paralyzedDrawUnitVBOTable.instanceIDtoIndex[unitID] then
		popElementInstance(paralyzedDrawUnitVBOTable, unitID)
	end
	paralyzeStrength[unitID] = nil
end

---  All the stuff from the old paralyze effect widget to make this shit work!
local TESTMODE = false

local myTeamID
local spec, fullview

local function AddIfParalyzed(unitID)
	local _, maxHealth, paralyzeDamage = spGetUnitHealth(unitID)
	if TESTMODE then
		DrawParalyzedUnitGL4(unitID)
	elseif paralyzeDamage and paralyzeDamage > 0 and DrawParalyzedUnitGL4(unitID) then
		SetParalyzeStrength(unitID, paralyzeDamage / maxHealth)
	end
end

local function init()
	InstanceVBOTable.clearInstanceTable(paralyzedDrawUnitVBOTable)
	paralyzeStrength = {}
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		AddIfParalyzed(allUnits[i])
	end
end

function widget:PlayerChanged(playerID)
	spec, fullview = Spring.GetSpectatingState()
	local prevMyTeamID = myTeamID
	myTeamID = Spring.GetLocalTeamID()
	if myTeamID ~= prevMyTeamID then -- TODO only really needed if onlyShowOwnTeam, or if allyteam changed?
		--spEcho("Initializing Paralyze Effect")
		init()
	end
end

function widget:UnitCreated(unitID)
	AddIfParalyzed(unitID)
end

function widget:UnitDestroyed(unitID)
	StopDrawParalyzedUnitGL4(unitID)
end

function widget:UnitLeftLos(unitID)
	-- Spectators with fullview see all units regardless of LOS; don't strip the
	-- effect on LOS-leave because UnitEnteredLos early-returns under fullview
	-- and would never restore it (causes effect to vanish from paralyzed units).
	if fullview then
		return
	end
	StopDrawParalyzedUnitGL4(unitID)
end

function widget:UnitEnteredLos(unitID)
	if fullview then
		return
	end
	AddIfParalyzed(unitID)
end

local toremove = {}

function widget:GameFrame(n)
	if TESTMODE or n % 3 ~= 0 then
		return
	end
	local removeCount = 0
	for unitID in pairs(paralyzedDrawUnitVBOTable.instanceIDtoIndex) do
		local _, maxHealth, paralyzeDamage = spGetUnitHealth(unitID)
		if paralyzeDamage and paralyzeDamage > 0 then
			SetParalyzeStrength(unitID, paralyzeDamage / maxHealth)
		else
			removeCount = removeCount + 1
			toremove[removeCount] = unitID
		end
	end
	for i = 1, removeCount do
		StopDrawParalyzedUnitGL4(toremove[i])
		toremove[i] = nil
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	initGL4()
	init()
	if TESTMODE then
		for _, unitID in ipairs(spGetAllUnits()) do
			glSetUnitBufferUniforms(unitID, { 1.01 }, 4)
		end
	end
	WG.DrawParalyzedUnitGL4 = DrawParalyzedUnitGL4
	WG.StopDrawParalyzedUnitGL4 = StopDrawParalyzedUnitGL4
end

-- called from the Healthbars Widget Forwarding gadget on every paralyze hit
function widget:UnitParalyzeDamageEffect(unitID, unitDefID, damage)
	if not paralyzedDrawUnitVBOTable.instanceIDtoIndex[unitID] then
		AddIfParalyzed(unitID)
	end
end

function widget:Shutdown()
	WG.DrawParalyzedUnitGL4 = nil
	WG.StopDrawParalyzedUnitGL4 = nil
end

function widget:DrawWorld()
	if paralyzedDrawUnitVBOTable.usedElements > 0 then
		--if spGetGameFrame() % 90 == 0 then spEcho("Drawing paralyzed units #", paralyzedDrawUnitVBOTable.usedElements) end
		gl.Culling(GL.BACK)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		gl.DepthTest(true)
		gl.PolygonOffset(-2, -2)
		paralyzedUnitShader:Activate()
		--gl.Texture(0, "luaui/images/noisetextures/rgba_noise_256.tga")
		paralyzedDrawUnitVBOTable.VAO:Submit()
		paralyzedUnitShader:Deactivate()
		--gl.Texture(0, false)
		gl.PolygonOffset(false)
		--gl.DepthMask(true) --"BK OpenGL state resets", was true but now commented out (redundant set of false states)
		gl.Culling(false)
	end
end
