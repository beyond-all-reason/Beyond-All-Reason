function widget:GetInfo()
  return {
    name      = "Paralyze Effect GL4",
    version   = "v0.2",
    desc      = "Faster gl.UnitShape, Use WG.UnitShapeGL4",
    author    = "Beherith",
    date      = "2021.11.04",
    license   = "Lua Code: GPL V2, GLSL code: (c) Beherith (mysterme@gmail.com)",
    layer     = 0,
    enabled   = true,
  }
end

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevboidtable.lua") 

-- for testing: /luarules fightertest corak armpw 100 10 3000

local paralyzedUnitShader, unitShapeShader

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10000

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 T;
layout (location = 3) in vec3 B;
layout (location = 4) in vec4 uv;
layout (location = 5) in uint pieceIndex;
layout (location = 6) in vec4 startcolorpower;
layout (location = 7) in vec4 endcolor_endgameframe; 
layout (location = 8) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
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
    
    vec4 speed;    
    vec4[5] userDefined; //can't use float[20] because float in arrays occupies 4 * float space
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

	//uint teamIndex = (instData.y & 0x000000FFu); //leftmost ubyte is teamIndex
	//myTeamColor = vec4(teamColor[teamIndex].rgb, 1.0); // pass alpha through

	v_endcolor_alpha.rgba = endcolor_endgameframe.rgba;
	v_endcolor_alpha.a = clamp( (v_endcolor_alpha.a - timeInfo.x + 100) * 0.01, 0.0, 1.0); // fade out for end time

	float paralyzestrength = uni[instData.y].userDefined[1].x;
	v_endcolor_alpha.a = clamp(pow(paralyzestrength, 3.0), 0.0, 1.0);
	if ((uni[instData.y].composite & 0x00000003u) < 1u ) v_endcolor_alpha.a = 0.0; // this checks the drawFlag of wether the unit is actually being drawn (this is ==1 when then unit is both visible and drawn as a full model (not icon)) 
	
	v_startcolorpower = startcolorpower;
	gl_Position = cameraViewProj * modelPos;
}
]]

local fsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

uniform sampler2D tex1;

// NOISE:
const vec2 zOffset = vec2(37.0,17.0);
const vec2 wOffset = vec2(59.0,83.0);

vec4 tex(vec2 uv)	// Emulate a single texture fetch into the precalculated texture
{
	// NOTE: Precalculate texture (that somehow failed), so we can do a single fetch instead of 4.
	float r = textureLod( tex1, (uv+0.5)/256.0, 0.0 ).b;
	float g = textureLod( tex1, (uv+0.5 + zOffset)/256.0, 0.0 ).b;
	float b = textureLod( tex1, (uv+0.5 + wOffset)/256.0, 0.0 ).b;
	float a = textureLod( tex1, (uv+0.5 + zOffset + wOffset)/256.0, 0.0 ).b;
	//vec4 rgba = textureLod( tex1, (uv+0.5)/256.0, 0.0 );
	//return rgba.rgba;
	return vec4(r, g, b, a);
}

float noise( in vec4 x )
{
	vec4 p = floor(x);
	vec4 f = fract(x);
	f = f*f*(3.0-2.0*f);
	vec2 uv = (p.xy + p.z*zOffset + p.w*wOffset) + f.xy;
	vec4 s = tex(uv);
	return mix(mix( s.x, s.y, f.z ), mix(s.z, s.w, f.z), f.w);
}

const mat4 noisematrix = mat4( 0.00,  0.80,  0.60, -0.4,
                    -0.80,  0.36, -0.48, -0.5,
                    -0.60, -0.48,  0.64,  0.2,
                     0.40,  0.30,  0.20,  0.4);
// END NOISE

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec3 v_modelPosOrig;
in vec4 v_startcolorpower;
in vec4 v_endcolor_alpha;

out vec4 fragColor;
#line 25000
void main() {
	
	vec4 noiseposition = 0.11*vec4(v_modelPosOrig, (timeInfo.x + timeInfo.w)*0.5);
	float noisevalue;
	noisevalue  = 0.5000*noise( noiseposition ); noiseposition = noisematrix*noiseposition*2.01;
	noisevalue += 0.2500*noise( noiseposition ); noiseposition = noisematrix*noiseposition*2.02;
	noisevalue += 0.1250*noise( noiseposition ); noiseposition = noisematrix*noiseposition*2.03;
	noisevalue += 0.0625*noise( noiseposition ); noiseposition = noisematrix*noiseposition*2.04;
	
	float electricity = clamp(1.0 - abs(noisevalue  - 0.5)*5.0, 0.0, 1.0);
	electricity = pow(electricity, v_startcolorpower.w);
	vec3 lightcolor = mix(v_endcolor_alpha.rgb, v_startcolorpower.rgb, electricity);
	
	fragColor = vec4(lightcolor, electricity*v_endcolor_alpha.a);
	//fragColor = vec4(vec3(electricity), 1.0);
	//fragColor = vec4(1.0);
}
]]

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

	paralyzedUnitShader = LuaShader({
		vertex = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
		fragment = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
		uniformInt = {
			tex1 = 0,
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
	
	--Spring.Echo("DrawParalyzedUnitGL4",unitID, unitDefID)
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
	widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
end

local function UnitParalyzeDamageEffect(unitID, unitDefID, damage) -- called from Healthbars Widget Forwarding GADGET!!!
	--Spring.Echo("UnitParalyzeDamageEffect",unitID, unitDefID, damage, Spring.GetUnitIsStunned(unitID)) -- DO NOTE THAT: return: nil | bool stunned_or_inbuild, bool stunned, bool inbuild
	
	widget:UnitCreated(unitID, unitDefID)
end

local uniformcache = {0}
local toremove = {}

function widget:GameFrame(n)
	if n % 3 == 0 then
		for unitID, index in pairs(paralyzedDrawUnitVBOTable.instanceIDtoIndex) do 
			local health, maxHealth, paralyzeDamage, capture, build = Spring.GetUnitHealth(unitID)
			uniformcache[1] = paralyzeDamage / maxHealth
			gl.SetUnitBufferUniforms(unitID, uniformcache, 4) 
			if paralyzeDamage == 0 then 
				toremove[unitID] = true
			end
		end
	end
	for unitID, _ in pairs(toremove) do 
		StopDrawParalyzedUnitGL4(unitID)
		toremove[unitID] = nil
	end
end

function widget:Initialize()
	initGL4()
	if TESTMODE then
		for i, unitID in ipairs(Spring.GetAllUnits()) do
			widget:UnitCreated(unitID)
		end
	end
	init()
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
		gl.DepthMask(true)
		gl.DepthTest(true)
		gl.PolygonOffset( -2 ,-2) 
		paralyzedUnitShader:Activate()
		gl.Texture(0, "luaui/images/rgba_noise_256.tga")
		paralyzedDrawUnitVBOTable.VAO:Submit()
		paralyzedUnitShader:Deactivate()
		gl.Texture(0, false)
		gl.PolygonOffset( false ) 
		gl.Culling(false)
	end
end