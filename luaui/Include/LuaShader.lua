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

	vec4 timeInfo; //gameFrame, gameSeconds, drawFrame, frameTimeOffset
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
			if vsSrcNew then 
				vsSrcNew = vsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				vsSrcNew = vsSrcNew:gsub("//__DEFINES__", shaderDefines)
				shadersourcecache.vsSrcComplete = vsSrcNew
			end
			if fsSrcNew then 
				fsSrcNew = fsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				fsSrcNew = fsSrcNew:gsub("//__DEFINES__", shaderDefines)
				shadersourcecache.fsSrcComplete = fsSrcNew
			end
			if gsSrcNew then 
				gsSrcNew = gsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				gsSrcNew = gsSrcNew:gsub("//__DEFINES__", shaderDefines)
				shadersourcecache.gsSrcComplete = gsSrcNew
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

	self.shaderObj = gl.CreateShader(self.shaderParams)
	local shaderObj = self.shaderObj

	local shLog = gl.GetShaderLog() or ""
	self.shLog = shLog
	if not shaderObj then
		self:ShowError(shLog)
		return false
	elseif (shLog ~= "") and suppresswarnings ~= true then
		self:ShowWarning(shLog)
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
		self.active = true
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
