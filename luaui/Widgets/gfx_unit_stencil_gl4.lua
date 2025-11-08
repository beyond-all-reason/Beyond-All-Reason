local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Unit Stencil GL4",
		desc      = "A fun approach to minimizing the cost of some fun shaders",
		author    = "Beherith",
		date      = "2022.03.05",
		license   = "GNU GPL, v2 or later",
		layer     = 50,
		enabled   = true,
		depends   = {'gl4'},
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spEcho = Spring.Echo

-- Key Idea: make a 1/2 or 1/4 sized texture 'stencil buffer' that can be used for units and features.
-- Draw features first at 0.5, then units at 1.0, clear if no draw happened
-- Make this shared the same way screencopy texture is shared, via an api
-- bind and sample this texture if needed for any other method :)

local unitStencilVBO = nil
local featureStencilVBO = nil -- TODO
local unitStencilShader = nil

local unitFeatureStencilTex = nil

local unitDimensionsXYZ = {} -- table of unitDefID to max x,y,z dims
local featureDimensionsXYZ = {} -- table of unitDefID to max x,y,z dims
-----------------------------------------------------------------
-- Configuration Constants
-----------------------------------------------------------------
local addRadius = 10
-----------------------------------------------------------------
-- GL4 Backend Stuff

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local vsSrc =  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

layout (location = 0) in vec4 unitModelMinXYZ;
layout (location = 1) in vec4 unitModelMaxXYZ;
layout (location = 2) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

struct SUniformsBuffer {
    uint composite; //   u8 drawFlag; u8 unused1; u16 id;
    
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

#line 10000

uniform float addRadius = 10;

out DataVS {
	vec4 v_unitModelMinXYZ;
    vec4 v_unitModelMaxXYZ;
    vec4 v_centerPos;
};

void main()
{
	gl_Position = cameraViewProj * vec4(uni[instData.y].drawPos.xyz, 1.0); // We transform this vertex into the center of the model
    v_unitModelMinXYZ = unitModelMinXYZ;
    v_unitModelMaxXYZ = unitModelMaxXYZ;
    v_unitModelMaxXYZ.w = 1.0;
    v_centerPos = vec4(uni[instData.y].drawPos);
    // TODO: calculate radius in screen-space pixels

    // Make no primitives on stuff outside of screen
    if (isSphereVisibleXY(vec4(uni[instData.y].drawPos.xyz, 1.0), addRadius + unitModelMaxXYZ.x + unitModelMaxXYZ.z)) 
    v_unitModelMaxXYZ.w = 0.0; 

    // this checks the drawFlag of wether the unit is actually being drawn 
    // (this is ==1 when then unit is both visible and drawn as a full model (not icon)) 
    if ((uni[instData.y].composite & 0x00000003u) < 1u ) 
    v_unitModelMaxXYZ.w = 0.0; 
}
]]

local gsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
layout(points) in;
layout(triangle_strip, max_vertices = 12) out;
#line 20000

uniform float addRadius = 10;

in DataVS {
	vec4 v_unitModelMinXYZ;
    vec4 v_unitModelMaxXYZ;
    vec4 v_centerPos;
} dataIn[];

mat3 rotY;
vec4 centerpos;

void offsetVertex4( float x, float y, float z){
	vec3 primitiveCoords = vec3(x,y,z);
    primitiveCoords*= 1;
	vec3 vecnorm = sign(primitiveCoords);
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * ( vec3(addRadius ,0,addRadius)* vecnorm + primitiveCoords ), 1.0);
	EmitVertex();
}

#line 22000
void main(){
    vec4 Mins =  dataIn[0].v_unitModelMinXYZ;
    vec4 Maxs =  dataIn[0].v_unitModelMaxXYZ;
    if (Maxs.w < 0.5) return;
	centerpos = dataIn[0].v_centerPos;

    vec3 camPos = cameraViewInv[3].xyz ;
	vec3 camDir = normalize(camPos-centerpos.xyz);

    float s = sin(centerpos.w);
	float c = cos(centerpos.w);

    rotY =  mat3(
        c, 0.0, -s,
        0.0, 1.0, 0.0,
        s, 0.0, c);


    // Draw Top Face
    offsetVertex4( Mins.x, Maxs.y,  Mins.z);
    offsetVertex4( Maxs.x, Maxs.y,  Mins.z);
    offsetVertex4( Mins.x, Maxs.y,  Maxs.z);
    offsetVertex4( Maxs.x, Maxs.y,  Maxs.z);
    EndPrimitive();
    
    float leftright = (dot(vec3(c, 0, -s), camDir) < 0) ? Mins.x : Maxs.x;
        offsetVertex4( leftright, Maxs.y,  Mins.z);
        offsetVertex4( leftright, Maxs.y,  Maxs.z);
        offsetVertex4( leftright, Mins.y,  Mins.z);
        offsetVertex4( leftright, Mins.y,  Maxs.z);
        EndPrimitive();

        
    float frontback = (dot(vec3(s, 0, c), camDir) > 0) ? Maxs.z : Mins.z;
        offsetVertex4( Mins.x, Maxs.y,  frontback);
        offsetVertex4( Maxs.x, Maxs.y,  frontback);
        offsetVertex4( Mins.x, Mins.y,  frontback);
        offsetVertex4( Maxs.x, Mins.y,  frontback);
    
    EndPrimitive();
}
]]

local fsSrc =
[[
#version 150 compatibility

uniform float stencilColor = 1.0; // 1 if we are stenciling

void main(void)
{
    gl_FragColor = vec4(stencilColor,stencilColor,stencilColor,1.0);
}
]]

local function goodbye(reason)
	spEcho("Unit Stencil GL4 widget exiting with reason: "..reason)
end
local resolution = 4
local vsx, vsy  
function widget:ViewResize()
    local GL_R8 = 0x8229
    vsx, vsy = Spring.GetViewGeometry()
    if unitFeatureStencilTex then gl.DeleteTexture(unitFeatureStencilTex) end
    unitFeatureStencilTex = gl.CreateTexture(vsx/resolution, vsy/resolution, {
		--format = GL.RGBA8,
        format = GL_R8,
		fbo = true,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
end


local function InitDrawPrimitiveAtUnit(modifiedShaderConf, DPATname)
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	gsSrc = gsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	local DrawPrimitiveAtUnitShader =  LuaShader(
		{
			vertex = vsSrc,
			fragment = fsSrc,
			geometry = gsSrc,
			uniformInt = {
				--DrawPrimitiveAtUnitTexture = 0;
			},
			uniformFloat = {
				addRadius = 1,
                stencilColor = 1,
			},
		},
		DPATname .. "Shader GL4"
	  )
	local shaderCompiled = DrawPrimitiveAtUnitShader:Initialize()
	if not shaderCompiled then
		goodbye("Failed to compile ".. DPATname .." GL4 ")
		return
	end

	unitStencilVBO = InstanceVBOTable.makeInstanceVBOTable(
		{
			{id = 0, name = 'unitModelMinXYZ', size = 4},
			{id = 1, name = 'unitModelMaxXYZ', size = 4},
			{id = 2, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		},
		64, -- maxelements
		DPATname .. "VBO", -- name
		2  -- unitIDattribID (instData)
	)

	unitStencilVBO.VAO  = gl.GetVAO()
	unitStencilVBO.VAO:AttachVertexBuffer(unitStencilVBO.instanceVBO)

    featureStencilVBO = InstanceVBOTable.makeInstanceVBOTable(
		{
			{id = 0, name = 'unitModelMinXYZ', size = 4},
			{id = 1, name = 'unitModelMaxXYZ', size = 4},
			{id = 2, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		},
		64, -- maxelements
		"featurestencil VBO", -- name
		2  -- unitIDattribID (instData)
	)
    
	featureStencilVBO.VAO  = gl.GetVAO()
	featureStencilVBO.VAO:AttachVertexBuffer(featureStencilVBO.instanceVBO)
    featureStencilVBO.featureIDs = true

	return DrawPrimitiveAtUnitShader
end

function widget:VisibleUnitAdded(unitID, unitDefID)
    if unitDimensionsXYZ[unitDefID] == nil then
        local unitDef = UnitDefs[unitDefID]
        unitDimensionsXYZ[unitDefID] = {
            unitDef.model.minx,  math.min(0, unitDef.model.miny), unitDef.model.minz,
            unitDef.model.maxx,  unitDef.model.maxy, unitDef.model.maxz,
        }
        local dimsXYZ  = unitDimensionsXYZ[unitDefID]
        --spEcho(dimsXYZ[1], dimsXYZ[2], dimsXYZ[3], dimsXYZ[4], dimsXYZ[5], dimsXYZ[6])
    end
    local dimsXYZ  = unitDimensionsXYZ[unitDefID]
	
	pushElementInstance(
		unitStencilVBO, -- push into this Instance VBO Table
		{
            dimsXYZ[1], dimsXYZ[2], dimsXYZ[3], 0, 
            dimsXYZ[4], dimsXYZ[5], dimsXYZ[6], 0,
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
		},
		unitID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		nil, -- noupload, dont use unless you know what you are doing
		unitID -- last one should be UNITID?
	)
end
function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(unitStencilVBO)
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID)
	end
end

function widget:VisibleUnitRemoved(unitID)
	if unitStencilVBO.instanceIDtoIndex[unitID] then
		popElementInstance(unitStencilVBO, unitID)
	end
end

function widget:FeatureCreated(featureID, allyTeam)
    local featureDefID = Spring.GetFeatureDefID(featureID)
    --spEcho(featureDefID, featureID)

    if featureDimensionsXYZ[featureDefID] == nil then
        local featureDef = FeatureDefs[featureDefID]
        if featureDef.model then 
            local dimsXYZ = {
                featureDef.model.minx,  featureDef.model.miny, featureDef.model.minz,
                featureDef.model.maxx,  featureDef.model.maxy, featureDef.model.maxz,
            }
            if (dimsXYZ[4] - dimsXYZ[1]) < 1 then return end -- goddamned geovents
            featureDimensionsXYZ[featureDefID] =dimsXYZ
            --spEcho(dimsXYZ[1], dimsXYZ[2], dimsXYZ[3], dimsXYZ[4], dimsXYZ[5], dimsXYZ[6])
        else
            return
        end
    end
    local dimsXYZ  = featureDimensionsXYZ[featureDefID]
	if dimsXYZ == nil then return end
	pushElementInstance(
		featureStencilVBO, -- push into this Instance VBO Table
		{
            dimsXYZ[1], dimsXYZ[2], dimsXYZ[3], 0, 
            dimsXYZ[4], dimsXYZ[5], dimsXYZ[6], 0,
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
		},
		featureID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		nil, -- noupload, dont use unless you know what you are doing
		featureID -- last one should be UNITID?
	)
end

function widget:FeatureDestroyed(featureID)
	if featureStencilVBO.instanceIDtoIndex[featureID] then
		popElementInstance(featureStencilVBO, featureID)
	end
end

local function DrawMe() -- about 0.025 ms
	if unitStencilVBO.usedElements > 0  or featureStencilVBO.usedElements > 0 then
        gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
		gl.Blending(GL.ONE, GL.ZERO)
        gl.Culling(false)
		unitStencilShader:Activate()
		unitStencilShader:SetUniform("addRadius", addRadius)
        if featureStencilVBO.usedElements > 0 then
            unitStencilShader:SetUniform("stencilColor", 0.5)
            featureStencilVBO.VAO:DrawArrays(GL.POINTS, featureStencilVBO.usedElements)
        end
        if unitStencilVBO.usedElements > 0 then 
            unitStencilShader:SetUniform("stencilColor", 1.0)
	    	unitStencilVBO.VAO:DrawArrays(GL.POINTS, unitStencilVBO.usedElements)
        end
		unitStencilShader:Deactivate()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end

function widget:DrawWorldPreUnit()
    --DrawMe()
end

local stencilRequested = false

function widget:DrawWorld()
    if stencilRequested then 
        gl.RenderToTexture(unitFeatureStencilTex, DrawMe)
        stencilRequested = false
    end
end

-- This shows the debug stencil texture
--[[ 
function widget:DrawScreen()
    gl.Color(1,1,1,1)
    gl.Blending(GL.ONE, GL.ZERO)
    gl.Texture(unitFeatureStencilTex)
	gl.TexRect(0, 0, vsx/resolution, vsy/resolution, 0, 0, 1, 1)
end
]]--

local function GetUnitStencilTexture()
    stencilRequested = true
    return unitFeatureStencilTex
end

function widget:Initialize()
	unitStencilShader = InitDrawPrimitiveAtUnit(shaderConfig, "unitStencils")
    widget:ViewResize()

    WG['unitstencilapi'] = {}
    WG['unitstencilapi'].GetUnitStencilTexture = GetUnitStencilTexture
    WG['unitstencilapi'].members = {ok = "yes", vsSrc = vsSrc, gsSrc = gsSrc, fsSrc = fsSrc, unitStencilVBO = unitStencilVBO, featureStencilVBO = featureStencilVBO}
	widgetHandler:RegisterGlobal('GetUnitStencilTexture', WG['unitstencilapi'].GetUnitStencilTexture)

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		local visibleUnits =  WG['unittrackerapi'].visibleUnits
		for unitID, unitDefID in pairs(visibleUnits) do
			widget:VisibleUnitAdded(unitID, unitDefID)
		end
        for _, featureID in ipairs(Spring.GetAllFeatures()) do
            widget:FeatureCreated(featureID)
        end
	end
end

function widget:Shutdown()
	gl.DeleteTexture(unitFeatureStencilTex)
	unitFeatureStencilTex = nil
	WG['unitstencilapi'] = nil
	widgetHandler:DeregisterGlobal('GetUnitStencilTexture')
end
