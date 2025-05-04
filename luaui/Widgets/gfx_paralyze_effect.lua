local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Paralyze Effect",
    version   = "v0.2",
    desc      = "Faster gl.UnitShape, Use WG.UnitShapeGL4",
    author    = "Beherith",
    date      = "2021.11.04",
    license   = "Lua Code: GPL V2, GLSL code: (c) Beherith (mysterme@gmail.com)",
    layer     = 0,
    enabled   = true,
  }
end

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevboidtable.lua")

-- for testing: /luarules fightertest corak armpw 100 10 3000

local paralyzedUnitShader, unitShapeShader

local shaderConfig = {
	SKINSUPPORT = Script.IsEngineMinVersion(105, 0, 1653) and 1 or 0,
}

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
#if (SKINSUPPORT == 0)
	layout (location = 5) in uint pieceIndex;
#else
	layout (location = 5) in uvec2 bonesInfo; //boneIDs, boneWeights
	#define pieceIndex (bonesInfo.x & 0x000000FFu)
#endif
layout (location = 6) in vec4 startcolorpower;
layout (location = 7) in vec4 endcolor_endgameframe;
layout (location = 8) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__

layout(std140, binding = 2) uniform FixedStateMatrices {
	mat4 modelViewMat;
	mat4 projectionMat;
	mat4 textureMat;
	mat4 modelViewProjectionMat;
};
#line 15000
//layout(std140, binding=0) readonly buffer MatrixBuffer {
layout(std140, binding=0) buffer MatrixBuffer {
	mat4 mat[];
};

mat4 GetPieceMatrix(bool staticModel) {
    return mat[instData.x + pieceIndex + uint(!staticModel)];
}

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
out vec4 v_startcolorpower;
out vec4 v_endcolor_alpha;

void main() {
	uint baseIndex = instData.x;
	mat4 modelMatrix = mat[baseIndex];

	uint isDynamic = 1u; //default dynamic model
	// dynamic models have one extra matrix, as their first matrix is their world pos/offset
	//mat4 pieceMatrix = mat4mix(mat4(1.0), mat[baseIndex + pieceIndex + isDynamic ], modelMatrix[3][3]);
	mat4 pieceMatrix = mat4mix(mat4(1.0), mat[baseIndex + pieceIndex + isDynamic ], 1.0);
	vec4 localModelPos = pieceMatrix * vec4(pos, 1.0);

	v_modelPosOrig = localModelPos.xyz + (modelMatrix[3].xyz)*0.3;
	vec4 modelPos = modelMatrix * localModelPos;

	v_endcolor_alpha.rgba = endcolor_endgameframe.rgba;
	v_endcolor_alpha.a = clamp( (v_endcolor_alpha.a - (timeInfo.x + timeInfo.w) + 100) * 0.01, 0.0, 1.0); // fade out for end time

	float paralyzestrength = uni[instData.y].userDefined[1].x; // this (paralyzedamage/maxhealth), so >=1.0 is paralyzed
	v_endcolor_alpha.a = clamp(pow(paralyzestrength, 2.0), 0.0, 1.1);
	if ((uni[instData.y].composite & 0x00000003u) < 1u ) v_endcolor_alpha.a = 0.0; // this checks the drawFlag of wether the unit is actually being drawn (this is ==1 when then unit is both visible and drawn as a full model (not icon))

	v_startcolorpower = startcolorpower;
	
	//v_endcolor_alpha.a = 0.99;
	gl_Position = cameraViewProj * modelPos;
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
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
float permute(float x){return floor(mod(((x*34.0)+1.0)*x, 289.0));}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
float taylorInvSqrt(float r){return 1.79284291400159 - 0.85373472095314 * r;}

vec4 grad4(float j, vec4 ip){
  const vec4 ones = vec4(1.0, 1.0, 1.0, -1.0);
  vec4 p,s;

  p.xyz = floor( fract (vec3(j) * ip.xyz) * 7.0) * ip.z - 1.0;
  p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
  s = vec4(lessThan(p, vec4(0.0)));
  p.xyz = p.xyz + (s.xyz*2.0 - 1.0) * s.www; 

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
  float j0 = permute( permute( permute( permute(i.w) + i.z) + i.y) + i.x);
  vec4 j1 = permute( permute( permute( permute (
             i.w + vec4(i1.w, i2.w, i3.w, 1.0 ))
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
in vec4 v_startcolorpower;
in vec4 v_endcolor_alpha;

out vec4 fragColor;
#line 25000
void main() {
	float paralysis_level = v_endcolor_alpha.a; // values of 1 are fully paralyzed 
	
	float noisescale;
	float persistance;
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
		persistance = 0.45;
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
		persistance = 0.45;
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
	noise4 += pow(persistance, 1.0) * snoise(noiseposition * 0.025 * pow(lacunarity, 1.0));
	noise4 += pow(persistance, 2.0) * snoise(noiseposition * 0.025 * pow(lacunarity, 2.0));
	noise4 += pow(persistance, 3.0) * snoise(noiseposition * 0.025 * pow(lacunarity, 3.0));
	noise4 += pow(persistance, 4.0) * snoise(noiseposition * 0.025 * pow(lacunarity, 4.0));
	noise4 = (1.0 * noise4 + 0.5);
	float electricity = clamp(1.0 - abs(noise4 - 0.5) * lighting_width, 0.0, 1.0);
	electricity = clamp(pow(electricity, lighting_sharpness), 0.0, 1.0);

	vec3 lightningcolor;
	float effectalpha;
	if (paralysis_level < 0.9999) { 
		//empreworktagdonotremove
		//empreworkherealsodonotremove
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

--holy hacks batman
if Spring.GetModOptions().emprework then
	fsSrc = string.gsub(fsSrc,'//empreworktagdonotremove','paralysis_level = paralysis_level*3; if (paralysis_level> 1) { paralysis_level = 1; }')
	fsSrc = string.gsub(fsSrc,'//empreworkherealsodonotremove','if (paralysis_level > 0.49) { wholeunitbasecolor = vec4(0.35, 0.43, 0.94, 0.18); }')
end

local paralyzedDrawUnitVBOTable

local function initGL4()
	local vertVBO = gl.GetVBO(GL.ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	local indxVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	vertVBO:ModelsVBO()
	indxVBO:ModelsVBO()

	local VBOLayout = {
			{id = 6, name = "startcolorpower", size = 4},
			{id = 7, name = "endcolor" , size = 4},
			{id = 8, name = "instData", type = GL.UNSIGNED_INT, size = 4},
		}

	local maxElements = 32 -- start small for testing
	local unitIDAttributeIndex = 8
	paralyzedDrawUnitVBOTable         = makeInstanceVBOTable(VBOLayout, maxElements, "paralyzedDrawUnitVBOTable", unitIDAttributeIndex, "unitID")

	paralyzedDrawUnitVBOTable.VAO = makeVAOandAttach(vertVBO, paralyzedDrawUnitVBOTable.instanceVBO, indxVBO)
	paralyzedDrawUnitVBOTable.indexVBO = indxVBO
	paralyzedDrawUnitVBOTable.vertexVBO = vertVBO

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig))
	fsSrc = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig))
		
	paralyzedUnitShader = LuaShader({
		vertex = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
		fragment = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
		uniformInt = {
			--tex1 = 0,
		},
	}, "paralyzedDrawparalyzedUnitShader")

	local paralyzedUnitShaderCompiled = paralyzedUnitShader:Initialize()
	if paralyzedUnitShaderCompiled ~= true  then
		Spring.Echo("paralyzedUnitShaderCompiled shader compilation failed", paralyzedUnitShaderCompiled, unitshapeshaderCompiled)
		widgetHandler:RemoveWidget()
	end
end

local function DrawParalyzedUnitGL4(unitID, unitDefID, red_start,  green_start, blue_start,power_start, red_end, green_end, blue_end, time_end)
	-- Documentation for DrawParalyzedUnitGL4:
	--	unitID: the actual unitID that you want to draw
	--	unitDefID: which unitDef is it (leave nil for autocomplete)
	-- returns: a unique handler ID number that you should store and call StopDrawParalyzedUnitGL4(uniqueID) with to stop drawing it
	-- note that widgets are responsible for stopping the drawing of every unit that they submit!

	--Spring.Echo("DrawParalyzedUnitGL4",unitID, unitDefID, UnitDefs[unitDefID].name)
	if paralyzedDrawUnitVBOTable.instanceIDtoIndex[unitID] then return end -- already got this unit
	if Spring.ValidUnitID(unitID) ~= true or Spring.GetUnitIsDead(unitID) == true then return end
	red_start = red_start or 1.0
	green_start = green_start or 1.0
	blue_start = blue_start or 1.0
	power_start = power_start or 4.0 
	red_end = red_end or 0
	green_end = green_end or 0
	blue_end = blue_end or 1.0
	time_end = 500000 --time_end or Spring.GetGameFrame()
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)

	pushElementInstance(paralyzedDrawUnitVBOTable , {
			red_start, green_start,blue_start, power_start,
			red_end, green_end, blue_end, time_end,
			0,0,0,0
		},
		unitID,
		true,
		nil,
		unitID,
		"unitID")
	--Spring.Echo("Pushed",  unitID, elementID)
	return unitID
end

local function StopDrawParalyzedUnitGL4(unitID)
	if paralyzedDrawUnitVBOTable.instanceIDtoIndex[unitID] then
		popElementInstance(paralyzedDrawUnitVBOTable, unitID)
	end
end

---  All the stuff from the old paralyze effect widget to make this shit work!
local unitIDtoUniqueID = {}
local TESTMODE = false

local gameFrame = Spring.GetGameFrame()
local prevGameFrame = gameFrame
local numParaUnits = 0
local myTeamID
local spec, fullview

local function init()
	clearInstanceTable(paralyzedDrawUnitVBOTable)
	local allUnits = Spring.GetAllUnits()
	for i=1, #allUnits do
		local unitID = allUnits[i]
		local health,maxHealth,paralyzeDamage,capture,build = Spring.GetUnitHealth(unitID)
		if paralyzeDamage and paralyzeDamage > 0 then
			widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
		end
	end
end

function widget:PlayerChanged(playerID)
	spec, fullview = Spring.GetSpectatingState()
	local prevMyTeamID = myTeamID
	myTeamID = Spring.GetMyTeamID()
	if myTeamID ~= prevMyTeamID then -- TODO only really needed if onlyShowOwnTeam, or if allyteam changed?
		--Spring.Echo("Initializing Paralyze Effect")
		init()
	end
end

function widget:UnitCreated(unitID, unitDefID)
	if TESTMODE then
		DrawParalyzedUnitGL4(unitID, unitDefID)
	end

	local health,maxHealth,paralyzeDamage,capture,build = Spring.GetUnitHealth(unitID)
	if paralyzeDamage and paralyzeDamage > 0 then
		DrawParalyzedUnitGL4(unitID, unitDefID)
	end
end

function widget:UnitDestroyed(unitID)
	StopDrawParalyzedUnitGL4(unitID)
end

function widget:UnitLeftLos(unitID)
	StopDrawParalyzedUnitGL4(unitID)
end

function widget:UnitEnteredLos(unitID)
	if fullview then return end
	widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
end

local function UnitParalyzeDamageEffect(unitID, unitDefID, damage) -- called from Healthbars Widget Forwarding GADGET!!!
	--Spring.Echo("UnitParalyzeDamageEffect",unitID, unitDefID, damage, Spring.GetUnitIsStunned(unitID)) -- DO NOTE THAT: return: nil | bool stunned_or_inbuild, bool stunned, bool inbuild

	widget:UnitCreated(unitID, unitDefID)
end

local uniformcache = {0}
local toremove = {}

function widget:GameFrame(n)
	if TESTMODE == false then 
		if n % 3 == 0 then
			for unitID, index in pairs(paralyzedDrawUnitVBOTable.instanceIDtoIndex) do
				local health, maxHealth, paralyzeDamage, capture, build = Spring.GetUnitHealth(unitID)
				if paralyzeDamage == 0 or paralyzeDamage == nil then
					toremove[unitID] = true
				else
					uniformcache[1] = (paralyzeDamage or 0) / (maxHealth or 1) -- 1 to avoid div0
					gl.SetUnitBufferUniforms(unitID, uniformcache, 4)
				end
			end
		end
		for unitID, _ in pairs(toremove) do
			StopDrawParalyzedUnitGL4(unitID)
			toremove[unitID] = nil
		end
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
		for i, unitID in ipairs(Spring.GetAllUnits()) do
			widget:UnitCreated(unitID)
			gl.SetUnitBufferUniforms(unitID, {1.01}, 4)
		end
	end
	WG['DrawParalyzedUnitGL4'] = DrawParalyzedUnitGL4
	WG['StopDrawParalyzedUnitGL4'] = StopDrawParalyzedUnitGL4
	widgetHandler:RegisterGlobal("UnitParalyzeDamageEffect",UnitParalyzeDamageEffect )
end

function widget:Shutdown()
	WG['DrawParalyzedUnitGL4'] = nil
	WG['StopDrawParalyzedUnitGL4'] = nil
	widgetHandler:DeregisterGlobal("UnitParalyzeDamageEffect" )
end

function widget:DrawWorld()
	if paralyzedDrawUnitVBOTable.usedElements > 0 then
		--if Spring.GetGameFrame() % 90 == 0 then Spring.Echo("Drawing paralyzed units #", paralyzedDrawUnitVBOTable.usedElements) end
		gl.Culling(GL.BACK)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		gl.DepthTest(true)
		gl.PolygonOffset( -2 ,-2)
		paralyzedUnitShader:Activate()
		--gl.Texture(0, "luaui/images/noisetextures/rgba_noise_256.tga")
		paralyzedDrawUnitVBOTable.VAO:Submit()
		paralyzedUnitShader:Deactivate()
		--gl.Texture(0, false)
		gl.PolygonOffset( false )
		--gl.DepthMask(true) --"BK OpenGL state resets", was true but now commented out (redundant set of false states)
		gl.Culling(false)
	end
end
