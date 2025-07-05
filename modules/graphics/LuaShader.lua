local UNIFORM_TYPE_MIXED        = 0 -- includes arrays; float or int
local UNIFORM_TYPE_INT          = 1 -- includes arrays
local UNIFORM_TYPE_FLOAT        = 2 -- includes arrays
local UNIFORM_TYPE_FLOAT_MATRIX = 3

local glGetUniformLocation = gl.GetUniformLocation
local glUseShader = gl.UseShader
local glActiveShader = gl.ActiveShader
local glUniform = gl.Uniform
local glUniformInt = gl.UniformInt
local glUniformMatrix = gl.UniformMatrix
local glUniformArray = gl.UniformArray

local gldebugannotations = (Spring.GetConfigInt("gldebugannotations") == 1)

local function new(class, shaderParams, shaderName, logEntries)
	local logEntriesSanitized
	if type(logEntries) == "number" then
		logEntriesSanitized = logEntries
	else
		logEntriesSanitized = 1
	end

	return setmetatable(
	{
		shaderName = shaderName or "Unnamed Shader",
		shaderParams = shaderParams or {},
		logEntries = logEntriesSanitized,
		logHash = {},
		shaderObj = nil,
		active = false,
		ignoreActive = false,
		ignoreUnkUniform = false,
		uniforms = {},
	}, class)
end

local function IsGeometryShaderSupported()
	return gl.HasExtension("GL_ARB_geometry_shader4") and (gl.SetShaderParameter ~= nil or gl.SetGeometryShaderParameter ~= nil)
end

local function IsTesselationShaderSupported()
	return gl.HasExtension("GL_ARB_tessellation_shader") and (gl.SetTesselationShaderParameter ~= nil)
end

local function IsDeferredShadingEnabled()
	return (Spring.GetConfigInt("AllowDeferredMapRendering") == 1) and (Spring.GetConfigInt("AllowDeferredModelRendering") == 1) and (Spring.GetConfigInt("AdvMapShading") == 1)
end

local function GetAdvShadingActive()
	local advUnitShading, advMapShading = Spring.HaveAdvShading()
	if advMapShading == nil then
		advMapShading = true
	end --old engine
	return advUnitShading and advMapShading
end

local function GetEngineUniformBufferDefs()
    local eubs = [[
layout(std140, binding = 0) uniform UniformMatrixBuffer {
	mat4 screenView;
	mat4 screenProj;
	mat4 screenViewProj;

	mat4 cameraView;
	mat4 cameraProj;
	mat4 cameraViewProj;
	mat4 cameraBillboardView;

	mat4 cameraViewInv;
	mat4 cameraProjInv;
	mat4 cameraViewProjInv;

	mat4 shadowView;
	mat4 shadowProj;
	mat4 shadowViewProj;

	mat4 reflectionView;
	mat4 reflectionProj;
	mat4 reflectionViewProj;

	mat4 orthoProj01;

	// transforms for [0] := Draw, [1] := DrawInMiniMap, [2] := Lua DrawInMiniMap
	mat4 mmDrawView; //world to MM
	mat4 mmDrawProj; //world to MM
	mat4 mmDrawViewProj; //world to MM

	mat4 mmDrawIMMView; //heightmap to MM
	mat4 mmDrawIMMProj; //heightmap to MM
	mat4 mmDrawIMMViewProj; //heightmap to MM

	mat4 mmDrawDimView; //mm dims
	mat4 mmDrawDimProj; //mm dims
	mat4 mmDrawDimViewProj; //mm dims
};

layout(std140, binding = 1) uniform UniformParamsBuffer {
	vec3 rndVec3; //new every draw frame.
	uint renderCaps; //various render booleans

	vec4 timeInfo; //gameFrame, drawSeconds, interpolated(unsynced)GameSeconds(synced), frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize; //xz, xzPO2
	vec4 mapHeight; //height minCur, maxCur, minInit, maxInit

	vec4 fogColor; //fog color
	vec4 fogParams; //fog {start, end, 0.0, scale}

	vec4 sunDir; // (sky != nullptr) ? sky->GetLight()->GetLightDir() : float4(/*map default*/ 0.0f, 0.447214f, 0.894427f, 1.0f);

	vec4 sunAmbientModel;
	vec4 sunAmbientMap;
	vec4 sunDiffuseModel;
	vec4 sunDiffuseMap;
	vec4 sunSpecularModel; // float4{ sunLighting->modelSpecularColor.xyz, sunLighting->specularExponent };
	vec4 sunSpecularMap; //  float4{ sunLighting->groundSpecularColor.xyz, sunLighting->specularExponent };

	vec4 shadowDensity; //  float4{ sunLighting->groundShadowDensity, sunLighting->modelShadowDensity, 0.0, 0.0 };

	vec4 windInfo; // windx, windy, windz, windStrength
	vec2 mouseScreenPos; //x, y. Screen space.
	uint mouseStatus; // bits 0th to 32th: LMB, MMB, RMB, offscreen, mmbScroll, locked
	uint mouseUnused;
	vec4 mouseWorldPos; //x,y,z; w=0 -- offmap. Ignores water, doesn't ignore units/features under the mouse cursor

	vec4 teamColor[255]; //all team colors
};

// glsl rotate convencience funcs: https://github.com/dmnsgn/glsl-rotate

mat3 rotation3dX(float angle) {
	float s = sin(angle);
	float c = cos(angle);

	return mat3(
		1.0, 0.0, 0.0,
		0.0, c, s,
		0.0, -s, c
	);
}

mat3 rotation3dY(float a) {
	float s = sin(a);
	float c = cos(a);

  return mat3(
    c, 0.0, -s,
    0.0, 1.0, 0.0,
    s, 0.0, c);
}

mat3 rotation3dZ(float angle) {
	float s = sin(angle);
	float c = cos(angle);

	return mat3(
		c, s, 0.0,
		-s, c, 0.0,
		0.0, 0.0, 1.0
	);
}

mat4 scaleMat(vec3 s) {
	return mat4(
		s.x, 0.0, 0.0, 0.0,
		0.0, s.y, 0.0, 0.0,
		0.0, 0.0, s.z, 0.0,
		0.0, 0.0, 0.0, 1.0
	);
}

mat4 translationMat(vec3 t) {
	return mat4(
		1.0, 0.0, 0.0, 0.0,
		0.0, 1.0, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		t.x, t.y, t.z, 1.0
	);
}

mat4 mat4mix(mat4 a, mat4 b, float alpha) {
	return (a * (1.0 - alpha) + b * alpha);
}

// Additional helper functions useful in Spring

vec2 heightmapUVatWorldPos(vec2 worldpos){
	vec2 inverseMapSize = vec2(1.0) / mapSize.xy;
	// Some texel magic to make the heightmap tex perfectly align:
	vec2 heightmaptexel = vec2(8.0, 8.0);
	worldpos +=  vec2(-8.0, -8.0) * (worldpos * inverseMapSize) + vec2(4.0, 4.0) ;
	vec2 uvhm = clamp(worldpos, heightmaptexel, mapSize.xy - heightmaptexel);
	uvhm = uvhm	* inverseMapSize;
	return uvhm;
}

// This does 'mirror' style tiling of UVs like the way the map edge extension works
vec2 heightmapUVatWorldPosMirrored(vec2 worldpos) {
	vec2 inverseMapSize = vec2(1.0) / mapSize.xy;
	// Some texel magic to make the heightmap tex perfectly align:
	vec2 heightmaptexel = vec2(8.0, 8.0);
	worldpos +=  vec2(-8.0, -8.0) * (worldpos * inverseMapSize) + vec2(4.0, 4.0) ;
	vec2 uvhm = worldpos * inverseMapSize;
	
	return abs(fract(uvhm * 0.5 + 0.5) - 0.5) * 2.0;
}

//  SphereInViewSignedDistance
//  Signed distance from a world-space sphere to the X-Y NDC box.
//  Z (near/far) is ignored. Very reliable, reasonably optimized. 
//  Returns:
//      < 0  – sphere at least partially inside the X-Y clip box
//      = 0  – sphere exactly touches at least one edge
//      > 0  – sphere is more distance from the edge of frustrum by that many NDC units
// 
float SphereInViewSignedDistance(vec3 centerWS,  float radiusWS)
{
    // 1.  centre → clip space
    vec4 clipC = cameraViewProj * vec4(centerWS, 1.0);
    if (clipC.w <= 0.0)           // behind the eye? treat as inside
        return -1.0;

    // 2.  NDC centre (one perspective divide, reused later)
    vec2  ndc   = clipC.xy / clipC.w;        // = clipC.xy / clipC.w

    // 3.  Project world-space +X displacement
    //     M * (p + (r,0,0,0)) = (M*p) + r*M*Xcol
    vec4 deltaClip = radiusWS * cameraViewProj[0];   // first column of matrix
    vec4 clipX     = clipC + deltaClip;

    // 4.  Radius in NDC (second perspective divide only once)
    float ndcRadius = length((clipX.xy / clipX.w) - ndc);

    // 5.  Four signed distances, keep the worst (Chebyshev / max)
    float dLeft   = -(ndc.x + 1.0) - ndcRadius;
    float dRight  =  (ndc.x - 1.0) - ndcRadius;
    float dBottom = -(ndc.y + 1.0) - ndcRadius;
    float dTop    =  (ndc.y - 1.0) - ndcRadius;

    return max(max(dLeft, dRight), max(dBottom, dTop));
}



// Note that this function does not check the Z or depth of the clip space, but in regular springrts top-down views, this isnt needed either. 
// the radius to cameradist ratio is a good proxy for visibility in the XY plane
bool isSphereVisibleXY(vec4 wP, float wR){ //worldPos, worldRadius
	vec3 ToCamera = wP.xyz - cameraViewInv[3].xyz; // vector from worldpos to camera
	float isqrtDistRatio = wR * inversesqrt(dot(ToCamera, ToCamera)); // calculate the relative screen-space size of it
	vec4 cWPpos = cameraViewProj * wP; // transform the worldpos into clip space
	vec2 clipVec = cWPpos.ww * (1.0 + isqrtDistRatio); // normalize the clip tolerance
	return any(greaterThan(abs(cWPpos.xy), clipVec)); // check if the clip space coords lie outside of the tolerance relaxed [-1.0, 1.0] space
}

/*
vec3 hsv2rgb(vec3 c){
	vec4 K=vec4(1.,2./3.,1./3.,3.);
	return c.z*mix(K.xxx,saturate(abs(fract(c.x+K.xyz)*6.-K.w)-K.x),c.y);
}

vec3 rgb2hsv(vec3 c){
	vec4 K=vec4(0.,-1./3.,2./3.,-1.);
	vec4 p=mix(vec4(c.bg ,K.wz),vec4(c.gb,K.xy ),step(c.b,c.g));
	vec4 q=mix(vec4(p.xyw,c.r ),vec4(c.r ,p.yzx),step(p.x,c.r));
	float d=q.x-min(q.w,q.y);
	float e=1e-10;
	return vec3(abs(q.z+(q.w-q.y)/(6.*d+e)),d/(q.x+e),q.x);
}
*/

]]


	local waterAbsorbColorR, waterAbsorbColorG, waterAbsorbColorB = gl.GetWaterRendering("absorb")
	local waterMinColorR, waterMinColorG, waterMinColorB = gl.GetWaterRendering("minColor")
	local waterBaseColorR, waterBaseColorG, waterBaseColorB = gl.GetWaterRendering("baseColor")

	local waterUniforms = 
[[ 
#define WATERABSORBCOLOR vec3(%f,%f,%f)
#define WATERMINCOLOR vec3(%f,%f,%f)
#define WATERBASECOLOR vec3(%f,%f,%f)
#define SMF_SHALLOW_WATER_DEPTH_INV 0.1

// vertex below shallow water depth --> alpha=1
// vertex above shallow water depth --> alpha=waterShadeAlpha
vec4 waterBlend(float fragmentheight){
	if (fragmentheight>=0) return vec4(0.0);
	vec4 waterBlendResult = vec4(1.0, 1.0, 1.0, 0.0);
	waterBlendResult.rgb = WATERBASECOLOR.rgb;
	waterBlendResult.rgb -= WATERABSORBCOLOR * clamp( -fragmentheight, 0, 1023);
	waterBlendResult.rgb = max(waterBlendResult.rgb, WATERMINCOLOR);
	waterBlendResult.a = clamp(-fragmentheight * SMF_SHALLOW_WATER_DEPTH_INV, 0.0, 1.0);
	return waterBlendResult;
}
]]
	waterUniforms = string.format(waterUniforms, 
		waterAbsorbColorR, waterAbsorbColorG, waterAbsorbColorB,
		waterMinColorR, waterMinColorG, waterMinColorB, 
		waterBaseColorR, waterBaseColorG, waterBaseColorB
	)

    return eubs .. waterUniforms
end
local function GetQuaternionDefs()
	-- For replacing //__QUATERNIONDEFS__ with the quaternion definitions
	return	[[
// Quaternion math functions
struct Transform {
	vec4 quat;
	vec4 trSc;
};

layout(std140, binding = 0) readonly buffer TransformBuffer {
	Transform transforms[];
};

uint GetUnpackedValue(uint packedValue, uint byteNum) {
	return (packedValue >> (8u * byteNum)) & 0xFFu;
}

vec4 MultiplyQuat(vec4 a, vec4 b)
{
    return vec4(a.w * b.xyz + b.w * a.xyz + cross(a.xyz, b.xyz), a.w * b.w - dot(a.xyz, b.xyz));
}

vec3 RotateByQuaternion(vec4 q, vec3 v) {
	return 2.0 * dot(q.xyz, v) * q.xyz + (q.w * q.w - dot(q.xyz, q.xyz)) * v + 2.0 * q.w * cross(q.xyz, v);
}

vec4 RotateByQuaternion(vec4 q, vec4 v) {
	return vec4(RotateByQuaternion(q, v.xyz), v.w);
}

vec4 InvertNormalizedQuaternion(vec4 q) {
	return vec4(-q.x, -q.y, -q.z, q.w);
}

vec3 ApplyTransform(Transform tra, vec3 v) {
	return RotateByQuaternion(tra.quat, v * tra.trSc.w) + tra.trSc.xyz;
}

vec4 ApplyTransform(Transform tra, vec4 v) {
	return vec4(RotateByQuaternion(tra.quat, v.xyz * tra.trSc.w) + tra.trSc.xyz * v.w, v.w);
}

Transform ApplyTransform(Transform parentTra, Transform childTra) {
	return Transform(
		MultiplyQuat(parentTra.quat, childTra.quat),
		vec4(
			parentTra.trSc.xyz + RotateByQuaternion(parentTra.quat, parentTra.trSc.w * childTra.trSc.xyz),
			parentTra.trSc.w * childTra.trSc.w
		)
	);
}

Transform InvertTransformAffine(Transform tra) {
	vec4 invR = InvertNormalizedQuaternion(tra.quat);
	float invS = 1.0 / tra.trSc.w;
	return Transform(
		invR,
		vec4(
			RotateByQuaternion(invR, -tra.trSc.xyz * invS),
			invS
		)
	);
}

mat4 TransformToMatrix(Transform tra) {
	float qxx = tra.quat.x * tra.quat.x;
	float qyy = tra.quat.y * tra.quat.y;
	float qzz = tra.quat.z * tra.quat.z;
	float qxz = tra.quat.x * tra.quat.z;
	float qxy = tra.quat.x * tra.quat.y;
	float qyz = tra.quat.y * tra.quat.z;
	float qrx = tra.quat.w * tra.quat.x;
	float qry = tra.quat.w * tra.quat.y;
	float qrz = tra.quat.w * tra.quat.z;

	mat3 rot = mat3(
		vec3(1.0 - 2.0 * (qyy + qzz), 2.0 * (qxy + qrz)      , 2.0 * (qxz - qry)      ),
		vec3(2.0 * (qxy - qrz)      , 1.0 - 2.0 * (qxx + qzz), 2.0 * (qyz + qrx)      ),
		vec3(2.0 * (qxz + qry)      , 2.0 * (qyz - qrx)      , 1.0 - 2.0 * (qxx + qyy))
	);

	rot *= tra.trSc.w;

	return mat4(
		vec4(rot[0]      , 0.0),
		vec4(rot[1]      , 0.0),
		vec4(rot[2]      , 0.0),
		vec4(tra.trSc.xyz, 1.0)
	);
}
vec4 SLerp(vec4 qa, vec4 qb, float t) {
	// Calculate angle between them.
	float cosHalfTheta = dot(qa, qb);

	// Every rotation can be represented by two quaternions: (++++) or (----)
	// avoid taking the longer way: choose one representation
	float s = sign(cosHalfTheta);
	qb *= s;
	cosHalfTheta *= s;
	// now cosHalfTheta is >= 0.0

	// if qa and qb (or -qb originally) represent ~ the same rotation
	if (cosHalfTheta >= (1.0 - 0.005))
		return normalize(mix(qa, qb, t));

	// Interpolation of orthogonal rotations (i.e. cosHalfTheta ~ 0)
	// does not require special handling, however this usually represents
	// "physically impossible" 180 degree turns with infinite speed so perhaps
	// it can be handled in the following (cuurently disabled) special way
	#if 0
	if (cosHalfTheta <= 0.005)
		return mix(qa, qb, step(0.5, t));
	#endif

	float halfTheta = acos(cosHalfTheta);

	// both should be divided by sinHalfTheta (calculation skipped),
	// but it makes no sense to do it due to follow up normalization
	float ratioA = sin((1.0 - t) * halfTheta);
	float ratioB = sin((      t) * halfTheta);

	return qa * ratioA + qb * ratioB; // already normalized
}

vec4 Lerp(vec4 qa, vec4 qb, float t) {
	// Ensure shortest path
	if (dot(qa, qb) < 0.0)
		qb = -qb;
	return normalize(mix(qa, qb, t)); // GLSL's mix() = (1 - t) * qa + t * qb
}

Transform SLerp(Transform t0, Transform t1, float a) {
	// generally good idea, otherwise extrapolation artifacts
	// will be nasty in some cases (e.g. fast rotation)
	a = clamp(a, 0.0, 1.0);
	return Transform(
		SLerp(t0.quat, t1.quat, a),
		mix(t0.trSc, t1.trSc, a)
	);
}


Transform Lerp(Transform t0, Transform t1, float a) {
	// generally good idea, otherwise extrapolation artifacts
	// will be nasty in some cases (e.g. fast rotation)
	a = clamp(a, 0.0, 1.0);
	return Transform(
		Lerp(t0.quat, t1.quat, a),
		mix(t0.trSc, t1.trSc, a)
	);
}



// This helper function gets the transform that gets you the model-space to world-space transform
Transform GetModelWorldTransform(uint baseIndex)
{
	return Lerp(
		transforms[baseIndex + 0u],
		transforms[baseIndex + 1u],
		timeInfo.w
	);
}

// This helper function gets the transform that gets you the piece-space to model-space transform
Transform GetPieceModelTransform(uint baseIndex, uint pieceID)
{
	return Lerp(
		transforms[baseIndex + 2u * (1u + pieceID) + 0u],
		transforms[baseIndex + 2u * (1u + pieceID) + 1u],
		timeInfo.w
	);
}

// This helper function gets the transform that gets you the piece-space to world-space transform
Transform GetPieceWorldTransform(uint baseIndex, uint pieceID)
{
	Transform pieceToMModelTX =  GetPieceModelTransform(baseIndex, pieceID);

	Transform modelToWorldTX = GetModelWorldTransform(baseIndex);

	return ApplyTransform(modelToWorldTX, pieceToMModelTX);
}

Transform GetStaticPieceModelTransform(uint baseIndex, uint pieceID)
{
	return transforms[baseIndex + 1u * (pieceID) + 0u];
}
	
]]
end

local function CreateShaderDefinesString(args) -- Args is a table of stuff that are the shader parameters
  local defines = {}
  for k, v in pairs (args) do
      defines[#defines + 1] = string.format("#define %s %s\n", tostring(k), tostring(v))
  end
  return table.concat(defines)
end


local LuaShader = setmetatable({}, {
	__call = function(self, ...) return new(self, ...) end,
	})
LuaShader.__index = LuaShader
LuaShader.isGeometryShaderSupported = IsGeometryShaderSupported()
LuaShader.isTesselationShaderSupported = IsTesselationShaderSupported()
LuaShader.isDeferredShadingEnabled = IsDeferredShadingEnabled()
LuaShader.GetAdvShadingActive = GetAdvShadingActive
LuaShader.GetEngineUniformBufferDefs = GetEngineUniformBufferDefs
LuaShader.CreateShaderDefinesString = CreateShaderDefinesString
LuaShader.GetQuaternionDefs = GetQuaternionDefs


local function CheckShaderUpdates(shadersourcecache, delaytime)
	-- todo: extract shaderconfig
	if shadersourcecache.forceupdate or shadersourcecache.lastshaderupdate == nil or 
		Spring.DiffTimers(Spring.GetTimer(), shadersourcecache.lastshaderupdate) > (delaytime or 0.5) then 
		shadersourcecache.lastshaderupdate = Spring.GetTimer()
		local vsSrcNew = (shadersourcecache.vssrcpath and VFS.LoadFile(shadersourcecache.vssrcpath)) or shadersourcecache.vsSrc
		local fsSrcNew = (shadersourcecache.fssrcpath and VFS.LoadFile(shadersourcecache.fssrcpath)) or shadersourcecache.fsSrc
		local gsSrcNew = (shadersourcecache.gssrcpath and VFS.LoadFile(shadersourcecache.gssrcpath)) or shadersourcecache.gsSrc
		if vsSrcNew == shadersourcecache.vsSrc and 
			fsSrcNew == shadersourcecache.fsSrc and 
			gsSrcNew == shadersourcecache.gsSrc and 
			not shadersourcecache.forceupdate then 
			--Spring.Echo("No change in shaders")
			return nil
		else
			local compilestarttime = Spring.GetTimer()
			shadersourcecache.vsSrc = vsSrcNew
			shadersourcecache.fsSrc = fsSrcNew
			shadersourcecache.gsSrc = gsSrcNew
			shadersourcecache.forceupdate = nil
			shadersourcecache.updateFlag = true
			local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
			local shaderDefines = LuaShader.CreateShaderDefinesString(shadersourcecache.shaderConfig)
			local quaternionDefines = LuaShader.GetQuaternionDefs()

			local printfpattern =  "^[^/]*printf%s*%(%s*([%w_%.]+)%s*%)"
			local printf = nil
			if not fsSrcNew then 
				Spring.Echo("Warning: No fragment shader source found for", shadersourcecache.shaderName)
			end	
			local fsSrcNewLines = string.lines(fsSrcNew)
			for i, line in ipairs(fsSrcNewLines) do 
				--Spring.Echo(i,line)
				local glslvariable = line:match(printfpattern)
				if glslvariable then 
					--Spring.Echo("printf in fragment shader",i,  glslvariable, line)
					-- init our printf table
					
					-- Replace uncommented printf's with the function stub to set the SSBO data for that field

					-- Figure out wether the glsl variable is a float, vec2-4
					local glslvarcount = 1 -- default is 1
					local dotposition = string.find(glslvariable, "%.")
					local swizzle = 'x'
					if dotposition then 
						swizzle = string.sub(glslvariable, dotposition+1)
						glslvarcount = string.len(swizzle)
					end
					if glslvarcount>4 then 
						glslvarcount = 4
					end
					if not printf then printf = {} end 
					printf["vars"] = printf["vars"] or {}
					local vardata =  {name = glslvariable, count = glslvarcount, line = i, index = #printf["vars"], swizzle = swizzle, shaderstage = 'f'}
					table.insert(printf["vars"], vardata)   
					local replacementstring = string.format('if (all(lessThan(abs(mouseScreenPos.xy- (gl_FragCoord.xy + vec2(0.5, -1.5))),vec2(0.25) ))) {	printfData[%i].%s = %s;}	//printfData[INDEX] = vertexPos.xyzw;',
							vardata.index, string.sub('xyzw', 1, vardata.count), vardata.name
					)
					Spring.Echo(string.format("Replacing f:%d %s", i, line))   
					fsSrcNewLines[i] = replacementstring
				end
			end
			
			-- If any substitutions were made, reassemble the shader source
			if printf then 
				-- Define the shader storage buffer object, with at most SSBOSize entries
				printf.SSBOSize = math.max(#printf['vars'], 16)
				--Spring.Echo("SSBOSize", printf.SSBOSize)
				printf.SSBO = gl.GetVBO(GL.SHADER_STORAGE_BUFFER)
				printf.SSBO:Define(printf.SSBOSize, {{id = 0, name = "printfData", size = 4}})
				local initZeros = {}
				for i=1, 4 * printf.SSBOSize  do initZeros[i] = 0 end
				printf.SSBO:Upload(initZeros)--, nil, 0)

				printf.SSBODefinition = [[
					layout (std430, binding = 7) buffer printfBuffer {
						vec4 printfData[];
					};
				]]

				-- Check shader version string and replace if required:
				
				for i, line in ipairs(fsSrcNewLines) do 
					if string.find(line, "#version", nil, true) then 
						if line ~= "#version 430 core" then 
							Spring.Echo("Replacing shader version", line, "with #version 430 core")
							fsSrcNewLines[i] = ""
							table.insert(fsSrcNewLines,1, "#version 430 core\n")
							break
						end
					end
				end
				
				-- Add required extensions

				local ssboextensions = {'#extension GL_ARB_shading_language_420pack: require',
										'#extension GL_ARB_uniform_buffer_object : require', 
										'#extension GL_ARB_shader_storage_buffer_object : require'}
				for j, ext in ipairs(ssboextensions) do
					local found = false
					for i, line in ipairs(fsSrcNewLines) do 
						if string.find(line, ext, nil, true) then 
							found = true
							break
						end
					end
					if not found then 
						table.insert(fsSrcNewLines, 2, ext) -- insert at position two as first pos is already taken by #version
					end
				end

				-- Reassemble the shader source by joining on newlines:
				fsSrcNew = table.concat(fsSrcNewLines, '\n')
				--Spring.Echo(fsSrcNew)
			end
			if vsSrcNew then 
				vsSrcNew = vsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				vsSrcNew = vsSrcNew:gsub("//__DEFINES__", shaderDefines)
				vsSrcNew = vsSrcNew:gsub("//__QUATERNIONDEFS__", quaternionDefines)
				shadersourcecache.vsSrcComplete = vsSrcNew
			end

			if gsSrcNew then 
				gsSrcNew = gsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				gsSrcNew = gsSrcNew:gsub("//__DEFINES__", shaderDefines)
				gsSrcNew = gsSrcNew:gsub("//__QUATERNIONDEFS__", quaternionDefines)
				shadersourcecache.gsSrcComplete = gsSrcNew
			end

			if fsSrcNew then 
				fsSrcNew = fsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", (printf and (engineUniformBufferDefs .. printf.SSBODefinition) or engineUniformBufferDefs))
				fsSrcNew = fsSrcNew:gsub("//__DEFINES__", shaderDefines)
				fsSrcNew = fsSrcNew:gsub("//__QUATERNIONDEFS__", quaternionDefines)
				shadersourcecache.fsSrcComplete = fsSrcNew -- the complete subbed cache should be kept as its needed to decipher lines post compilation errors
			end
			local reinitshader =  LuaShader(
				{
				vertex = vsSrcNew,
				fragment = fsSrcNew,
				geometry = gsSrcNew,
				uniformInt = shadersourcecache.uniformInt,
				uniformFloat = shadersourcecache.uniformFloat,
				},
				shadersourcecache.shaderName
			)
			local shaderCompiled = reinitshader:Initialize()
			if not shadersourcecache.silent then 
				Spring.Echo(shadersourcecache.shaderName, " recompiled in ", Spring.DiffTimers(Spring.GetTimer(), compilestarttime, true), "ms at", Spring.GetGameFrame(), "success", shaderCompiled or false)
			end
			if shaderCompiled then 
				reinitshader.printf = printf
				reinitshader.ignoreUnkUniform = true
				return reinitshader
			else
				return nil
			end
		end
	end
	return nil
end

LuaShader.CheckShaderUpdates = CheckShaderUpdates


local function lines(str)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end


function LuaShader:CreateLineTable()
	--[[
	-- self.shaderParams == 
			 ({[ vertex   = "glsl code" ,]
		   [ tcs      = "glsl code" ,]
		   [ tes      = "glsl code" ,]
		   [ geometry = "glsl code" ,]
		   [ fragment = "glsl code" ,]
		   [ uniform       = { uniformName = number value, ...} ,] (specify a Lua array as an argument to uniformName to initialize GLSL arrays)
		   [ uniformInt    = { uniformName = number value, ...} ,] (specify a Lua array as an argument to uniformName to initialize GLSL arrays)
		   [ uniformFloat  = { uniformName = number value, ...} ,] (specify a Lua array as an argument to uniformName to initialize GLSL arrays)
		   [ uniformMatrix = { uniformName = number value, ...} ,]
		   [ geoInputType = number inType,]
		   [ geoOutputType = number outType,]
		   [ geoOutputVerts = number maxVerts,]
		   [ definitions = "string of shader #defines", ]
		 })
	]]--
	
	local numtoline = {}
	
	--try to translate errors that look like this into lines: 
	--	0(31048) : error C1031: swizzle mask element not present in operand "ra"
	--	0(31048) : error C1031: swizzle mask element not present in operand "ra"
	--for k, v in pairs(self) do
	--	Spring.Echo(k)
	--end
	
	for _, shadertype in pairs({'vertex', 'tcs', 'tes', 'geometry', 'fragment', 'compute'}) do 
		if self.shaderParams[shadertype] ~= nil then 
			local shaderLines = (self.shaderParams.definitions or "") .. self.shaderParams[shadertype]
			local currentlinecount = 0
			for i, line in ipairs(lines(shaderLines)) do
				numtoline[currentlinecount] = string.format("%s:%i %s", shadertype, currentlinecount, line)
				--Spring.Echo(currentlinecount, numtoline[currentlinecount] )
				if line:find("#line ", nil, true) then 
					local defline = tonumber(line:sub(7)) 
					if defline then 
						currentlinecount = defline
					end
				else
				
					currentlinecount = currentlinecount + 1
				end
			end
		end
	end
	return numtoline
end

local function translateLines(alllines, errorcode) 
	if string.len(errorcode) < 3 then 
		return ("The shader compilation error code was very short. This likely means a Linker error, check the [in] [out] blocks linking VS/GS/FS shaders to each other to make sure the structs match")
	end
	local result = ""
	for _,line in pairs(lines(errorcode)) do 
		local pstart = line:find("(", nil, true)
		local pend = line:find(")", nil, true)
		local found = false
		if pstart and pend then 
			local lineno = line:sub(pstart +1,pend-1)
			--Spring.Echo(lineno)
			lineno = tonumber(lineno) 
			--Spring.Echo(lineno, alllines[lineno])
			if alllines[lineno] then 
				result = result .. string.format("%s\n ^^ %s \n", alllines[lineno], line)
				found = true
			end
		end
		if found == false then 
			result = result .. line ..'\n'
		end
	end
	return result
end



-----------------============ Warnings & Error Gandling ============-----------------
function LuaShader:OutputLogEntry(text, isError)
	local message

	local warnErr = (isError and "error") or "warning"

	message = string.format("LuaShader: [%s] shader %s(s):\n%s", self.shaderName, warnErr, text)
	Spring.Echo(message)
	
	if isError then 
		local linetable = self:CreateLineTable()
		Spring.Echo(translateLines(linetable, text))
	end


	if self.logHash[message] == nil then
	--	self.logHash[message] = 0
	end

	if false and self.logHash[message] <= self.logEntries then
		local newCnt = self.logHash[message] + 1
		self.logHash[message] = newCnt
		if (newCnt == self.logEntries) then
			message = message .. string.format("\nSupressing further %s of the same kind", warnErr)
		end
		Spring.Echo(message)
	end
end

function LuaShader:ShowWarning(text)
	self:OutputLogEntry(text, false)
end

function LuaShader:ShowError(text)
	self:OutputLogEntry(text, true)
end

-----------------============ Handle Ghetto Include<> ==============-----------------
local includeRegexps = {
	'.-#include <(.-)>.-',
	'.-#include \"(.-)\".-',
	'.-#pragma(%s+)include <(.-)>.-',
	'.-#pragma(%s+)include \"(.-)\".-',
}

function LuaShader:HandleIncludes(shaderCode, shaderName)
	local incFiles = {}
	local t1 = Spring.GetTimer()
	repeat
		local incFile
		local regEx
		for _, rx in ipairs(includeRegexps) do
			_, _, incFile = string.find(shaderCode, rx)
			if incFile then
				regEx = rx
				break
			end
		end

		Spring.Echo(shaderName, incFile)

		if incFile then
			shaderCode = string.gsub(shaderCode, regEx, '', 1)
			table.insert(incFiles, incFile)
		end
	until (incFile == nil)
	local t2 = Spring.GetTimer()
	Spring.Echo(Spring.DiffTimers(t2, t1, true))

	local includeText = ""
	for _, incFile in ipairs(incFiles) do
		if VFS.FileExists(incFile) then
			includeText = includeText .. VFS.LoadFile(incFile) .. "\n"
		else
			self:ShowError(string.format("Attempt to execute %s with file that does not exist in VFS", incFile))
			return false
		end
	end

	if includeText ~= "" then
		return includeText .. shaderCode
	else
		return shaderCode
	end
end

-----------------========= End of Handle Ghetto Include<> ==========-----------------

-----------------============ General LuaShader methods ============-----------------
function LuaShader:Compile(suppresswarnings)
	if not gl.CreateShader then
		self:ShowError("GLSL Shaders are not supported by hardware or drivers")
		return false
	end

-- LuaShader:HandleIncludes is too slow. Figure out faster way.
--[[
	for _, shaderType in ipairs({"vertex", "tcs", "tes", "geometry", "fragment"}) do
		if self.shaderParams[shaderType] then
			local newShaderCode = LuaShader:HandleIncludes(self.shaderParams[shaderType], self.shaderName)
			if newShaderCode then
				self.shaderParams[shaderType] = newShaderCode
			end
		end
	end
]]--

	local shaderObj, gl_program_id = gl.CreateShader(self.shaderParams)
	self.shaderObj = shaderObj
	self.gl_program_id = gl_program_id

	local shLog = gl.GetShaderLog() or ""
	self.shLog = shLog
	if not shaderObj then
		self:ShowError(shLog)
		return false
	elseif (shLog ~= "") and suppresswarnings ~= true then
		self:ShowWarning(shLog)
	end

	if gldebugannotations and gl_program_id and self.shaderName then 
		local GL_PROGRAM = 0x82E2
		gl.ObjectLabel(GL_PROGRAM, gl_program_id, self.shaderName)
	end

	local uniforms = self.uniforms
	for idx, info in ipairs(gl.GetActiveUniforms(shaderObj)) do
		local uniName = string.gsub(info.name, "%[0%]", "") -- change array[0] to array
		uniforms[uniName] = {
			location = glGetUniformLocation(shaderObj, uniName),
			--type = info.type,
			--size = info.size,
			values = {},
		}
		--Spring.Echo(uniName, uniforms[uniName].location, uniforms[uniName].type, uniforms[uniName].size)
		--Spring.Echo(uniName, uniforms[uniName].location)
	end
	
	-- Note that the function call overhead to the LuaShader:SetUniformFloat is about 500ns
	-- With this, a direct gl.Uniform call, this goes down to 100ns
	self.uniformLocations = {}
	for _, uniformGeneric in ipairs({self.shaderParams.uniformFloat or {}, self.shaderParams.uniformInt or {} }) do 
		for uniName, defaultvalue in pairs(uniformGeneric) do 
			local location = glGetUniformLocation(shaderObj, uniName) 
			if location then 
				self.uniformLocations[uniName] = location 
			else
				Spring.Echo(string.format("Notice from shader %s: Could not find location of uniform name: %s", "dunno", uniName ))
			end
			
		end
	end

	return true
end

LuaShader.Initialize = LuaShader.Compile

function LuaShader:GetHandle()
	if self.shaderObj ~= nil then
		return self.shaderObj
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		self:ShowError(string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()?", funcName))
	end
end

function LuaShader:Delete()
	if self.shaderObj ~= nil then
		gl.DeleteShader(self.shaderObj)
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		self:ShowError(string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()", funcName))
	end
end

LuaShader.Finalize = LuaShader.Delete

function LuaShader:Activate()
	if self.shaderObj ~= nil then
		-- bind the printf SSBO if present
		if self.printf then 
			local bindingIndex = self.printf.SSBO:BindBufferRange(7)
			if bindingIndex <= 0 then Spring.Echo("Failed to bind printfData SSBO for shader", self.shaderName) end
		end
		
		self.active = true
		if gldebugannotations and self.gl_program_id then
			gl.PushDebugGroup(self.gl_program_id * 1000, self.shaderName)
		end
		return glUseShader(self.shaderObj)
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		self:ShowError(string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()", funcName))
		return false
	end
end

function LuaShader:SetActiveStateIgnore(flag)
	self.ignoreActive = flag
end

function LuaShader:SetUnknownUniformIgnore(flag)
	self.ignoreUnkUniform = flag
end


function LuaShader:ActivateWith(func, ...)
	if self.shaderObj ~= nil then
		self.active = true
		glActiveShader(self.shaderObj, func, ...)
		self.active = false
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		self:ShowError(string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()", funcName))
	end
end

function LuaShader:Deactivate()
	self.active = false
	glUseShader(0)
	if gldebugannotations then gl.PopDebugGroup() end
	--Spring.Echo("LuaShader:Deactivate()")

	if self.printf then 
		--Spring.Echo("self.printf", self.printf)
		self.printf.SSBO:UnbindBufferRange(7)
		self.printf.bufferData = self.printf.SSBO:Download(-1, 0, nil, true) -- last param is forceGPURead = true
		--Spring.Echo(self.printf.bufferData[1],self.printf.bufferData[2],self.printf.bufferData[3],self.printf.bufferData[4])
		-- Do NAN checks on bufferData array and replace with -666 if NAN:
		for i = 1, #self.printf.bufferData do 
			if type(self.printf.bufferData[i]) == 'number' and (self.printf.bufferData[i] ~= self.printf.bufferData[i]) then -- check for NAN
				self.printf.bufferData[i] = -666
			end
		end

		if not self.DrawPrintf then 
			--Spring.Echo("creating DrawPrintf")
			local fontfile3 = "fonts/monospaced/" .. Spring.GetConfigString("bar_font3", "SourceCodePro-Semibold.otf")
			local fontSize = 16
			local font3 = gl.LoadFont(fontfile3, 32, 0.5, 1)
			
			local function DrawPrintf(sometimesself, xoffset, yoffset)
				--Spring.Echo("attempting to draw printf",xoffset)
				
				xoffset = xoffset or 0
				yoffset = yoffset or 0
				if type(sometimesself) == 'table' then 
					xoffset = xoffset or 0
					yoffset = yoffset or 0
				elseif type(sometimesself) == 'number' then 
					yoffset = xoffset
					xoffset = sometimesself
				end

				local mx,my = Spring.GetMouseState()
				mx = mx + xoffset
				my = my - 32 + yoffset

				gl.PushMatrix()
				font3:Begin()
				-- Todo: could really use a monospaced font!
				--gl.Color(1,1,1,1)
				gl.Blending(GL.ONE, GL.ZERO)
				for i, vardata in ipairs(self.printf.vars) do 
					local message 
					if vardata.count == 1 then 
						message = string.format("%s:%d %s = %.3f", vardata.shaderstage, vardata.line, vardata.name, self.printf.bufferData[1 + vardata.index * 4])
					elseif vardata.count == 2 then 
						message = string.format("%s:%d %s = [%.3f, %.3f]", vardata.shaderstage, vardata.line, vardata.name, self.printf.bufferData[1 + vardata.index * 4], self.printf.bufferData[2 + vardata.index * 4])
					elseif vardata.count == 3 then
						message = string.format("%s:%d %s = [%10.3f, %10.3f, %10.3f]", vardata.shaderstage, vardata.line, vardata.name, self.printf.bufferData[1 + vardata.index * 4], self.printf.bufferData[2 + vardata.index * 4], self.printf.bufferData[3 + vardata.index * 4])
					elseif vardata.count == 4 then
						message = string.format("%s:%d %s = [%.3f, %.3f, %.3f, %.3f]", vardata.shaderstage, vardata.line, vardata.name, self.printf.bufferData[1 + vardata.index * 4], self.printf.bufferData[2 + vardata.index * 4], self.printf.bufferData[3 + vardata.index * 4], self.printf.bufferData[4 + vardata.index * 4])
					end

					my = my - fontSize
					local vsx, vsy = Spring.GetViewGeometry()
					local alignment = ''
					if mx > (vsx - 400) then alignment = 'r' end
					--Spring.Echo(my,vsy) 
					font3:Print(message, math.floor(mx), math.floor(my), fontSize,alignment .."o"  )
				end
				
				gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				gl.PopMatrix()
				
				font3:End()
			end
			self.DrawPrintf = DrawPrintf
		end
	end
end


-----------------============ End of general LuaShader methods ============-----------------


-----------------============ Friend LuaShader functions ============-----------------
local function getUniformImpl(self, name)
	local uniform = self.uniforms[name]

	if uniform and type(uniform) == "table" then
		return uniform
	elseif uniform == nil then --used for indexed elements. nil means not queried for location yet
		local location = glGetUniformLocation(self.shaderObj, name)
		if location and location > -1 then
			self.uniforms[name] = {
				location = location,
				values = {},
			}
			return self.uniforms[name]
		else
			self.uniforms[name] = false --checked dynamic uniform name and didn't find it
		end
	end

	-- (uniform == false)
	return nil
end

local function getUniform(self, name)
	if not (self.active or self.ignoreActive) then
		self:ShowError(string.format("Trying to set uniform [%s] on inactive shader object. Did you use :Activate() or :ActivateWith()?", name))
		return nil
	end
	local uniform = getUniformImpl(self, name)
	if not (uniform ~= nil or self.ignoreUnkUniform) then
		self:ShowWarning(string.format("Attempt to set uniform [%s], which does not exist in the compiled shader", name))
		return nil
	end
	return uniform
end

local function isUpdateRequired(uniform, tbl)
	if (#tbl == 1) and (type(tbl[1]) == "string") then --named matrix
		return true --no need to update cache
	end

	local update = false
	local cachedValues = uniform.values
	for i, val in ipairs(tbl) do
		if cachedValues[i] ~= val then
			cachedValues[i] = val --update cache
			update = true
		end
	end

	return update
end

local function isUpdateRequiredNoTable(uniform, u1, u2, u3, u4)
	if (u2 == nil) and (type(u1) == "string") then --named matrix
		return true --no need to update cache
	end

	local update = false
	local cachedValues = uniform.values
	
	if u1 and cachedValues[1] ~= u1 then 
		update = true 
		cachedValues[1] = val 	
	end 
	if u2 and cachedValues[2] ~= u2 then 
		update = true 
		cachedValues[2] = u2	
	end 
	if u3 and cachedValues[3] ~= u3 then 
		update = true 
		cachedValues[3] = u3 	
	end 
	if u4 and cachedValues[4] ~= u4 then 
		update = true 
		cachedValues[4] = u4 	
	end 

	return update
end
-----------------============ End of friend LuaShader functions ============-----------------



-----------------============ LuaShader uniform manipulation functions ============-----------------
-- TODO: do it safely with types, len, size check

function LuaShader:GetUniformLocation(name)
	return (getUniform(self, name) or {}).location or -1
end

--FLOAT UNIFORMS
local function setUniformAlwaysImpl(uniform, u1, u2, u3, u4)
	if u4 ~= nil then 
		glUniform(uniform.location, u1, u2, u3, u4)
	elseif u3 ~= nil then 
		glUniform(uniform.location, u1, u2, u3)
	elseif u2 ~= nil then 
		glUniform(uniform.location, u1, u2)
	else
		glUniform(uniform.location, u1)
	end
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformAlways(name, u1, u2, u3, u4)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformAlwaysImpl(uniform, u1, u2, u3, u4)
end

local function setUniformImpl(uniform, u1, u2, u3, u4)
	if isUpdateRequiredNoTable(uniform, u1, u2, u3, u4) then
		return setUniformAlwaysImpl(uniform, u1, u2, u3, u4)
	end
	return true
end

function LuaShader:SetUniform(name, u1, u2, u3, u4)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformImpl(uniform, u1, u2, u3, u4)
end

LuaShader.SetUniformFloat = LuaShader.SetUniform
LuaShader.SetUniformFloatAlways = LuaShader.SetUniformAlways


--INTEGER UNIFORMS
local function setUniformIntAlwaysImpl(uniform,  u1, u2, u3, u4)
	if u4 ~= nil then 
		glUniformInt(uniform.location, u1, u2, u3, u4)
	elseif u3 ~= nil then 
		glUniformInt(uniform.location, u1, u2, u3)
	elseif u2 ~= nil then 
		glUniformInt(uniform.location, u1, u2)
	else
		glUniformInt(uniform.location, u1)
	end
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformIntAlways(name,  u1, u2, u3, u4)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntAlwaysImpl(uniform,  u1, u2, u3, u4)
end

local function setUniformIntImpl(uniform, u1, u2, u3, u4)
	if isUpdateRequiredNoTable(uniform, u1, u2, u3, u4) then
		return setUniformIntAlwaysImpl(uniform, u1, u2, u3, u4)
	end
	return true
end

function LuaShader:SetUniformInt(name,  u1, u2, u3, u4)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntImpl(uniform,  u1, u2, u3, u4)
end


--FLOAT ARRAY UNIFORMS
local function setUniformFloatArrayAlwaysImpl(uniform, tbl)
	glUniformArray(uniform.location, UNIFORM_TYPE_FLOAT, tbl)
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformFloatArrayAlways(name, tbl)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformFloatArrayAlwaysImpl(uniform, tbl)
end

local function setUniformFloatArrayImpl(uniform, tbl)
	if isUpdateRequired(uniform, tbl) then
		return setUniformFloatArrayAlwaysImpl(uniform, tbl)
	end
	return true
end

function LuaShader:SetUniformFloatArray(name, tbl)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformFloatArrayImpl(uniform, tbl)
end


--INT ARRAY UNIFORMS
local function setUniformIntArrayAlwaysImpl(uniform, tbl)
	glUniformArray(uniform.location, UNIFORM_TYPE_INT, tbl)
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformIntArrayAlways(name, tbl)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntArrayAlwaysImpl(uniform, tbl)
end

local function setUniformIntArrayImpl(uniform, tbl)
	if isUpdateRequired(uniform, tbl) then
		return setUniformIntArrayAlwaysImpl(uniform, tbl)
	end
	return true
end

function LuaShader:SetUniformIntArray(name, tbl)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntArrayImpl(uniform, tbl)
end


--MATRIX UNIFORMS
local function setUniformMatrixAlwaysImpl(uniform, tbl)
	glUniformMatrix(uniform.location, unpack(tbl))
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformMatrixAlways(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformMatrixAlwaysImpl(uniform, {...})
end

local function setUniformMatrixImpl(uniform, tbl)
	if isUpdateRequired(uniform, tbl) then
		return setUniformMatrixAlwaysImpl(uniform, tbl)
	end
	return true
end

function LuaShader:SetUniformMatrix(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformMatrixImpl(uniform, {...})
end
-----------------============ End of LuaShader uniform manipulation functions ============-----------------

return LuaShader
