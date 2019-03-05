local UNIFORM_TYPE_MIXED        = 0 -- includes arrays; float or int
local UNIFORM_TYPE_INT          = 1 -- includes arrays
local UNIFORM_TYPE_FLOAT        = 2 -- includes arrays
local UNIFORM_TYPE_FLOAT_MATRIX = 3


local function new(class, shaderParams, shaderName, logEntries)
	local logEntriesSanitized
	if type(logEntries) == "number" then
		logEntriesSanitized = logEntries
	else
		logEntriesSanitized = 3
	end

	return setmetatable(
	{
		shaderName = shaderName or "Unnamed Shader",
		shaderParams = shaderParams or {},
		logEntries = logEntriesSanitized,
		logHash = {},
		shaderObj = nil,
		active = false,
		uniforms = {},
	}, class)
end

local function isGeometryShaderSupported()
	return gl.HasExtension("GL_ARB_geometry_shader4") and (gl.SetShaderParameter ~= nil or gl.SetGeometryShaderParameter ~= nil)
end

local function isTesselationShaderSupported()
	return gl.HasExtension("GL_ARB_tessellation_shader") and (gl.SetTesselationShaderParameter ~= nil)
end

local function isDeferredShadingEnabled()
	return (Spring.GetConfigInt("AllowDeferredMapRendering") == 1) and (Spring.GetConfigInt("AllowDeferredModelRendering") == 1)
end


local LuaShader = setmetatable({}, {
	__call = function(self, ...) return new(self, ...) end,
	})
LuaShader.__index = LuaShader
LuaShader.isGeometryShaderSupported = isGeometryShaderSupported()
LuaShader.isTesselationShaderSupported = isTesselationShaderSupported()
LuaShader.isDeferredShadingEnabled = isDeferredShadingEnabled()

-----------------============ Warnings & Error Gandling ============-----------------
function LuaShader:OutputLogEntry(text, isError)
	local message

	local warnErr = (isError and "error") or "warning"

	message = string.format("LuaShader: [%s] shader %s(s):\n%s", self.shaderName, warnErr, text)

	if self.logHash[message] == nil then
		self.logHash[message] = 0
	end

	if self.logHash[message] <= self.logEntries then
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

		if incFile then
			shaderCode = string.gsub(shaderCode, regEx,'', 1)
			table.insert(incFiles, incFile)
		end
	until (incFile == nil)

	local includeText = ""
	for _, incFile in ipairs(incFiles) do
		if VFS.FileExists(incFile) then
			includeText = includeText .. VFS.LoadFile(incFile) .. "\n"
		else
			self:ShowError(string.format("Attempt to execute %s with file that does not exist in VFS", incFile))
			return false
		end
	end
	return includeText .. shaderCode
end

-----------------========= End of Handle Ghetto Include<> ==========-----------------

-----------------============ General LuaShader methods ============-----------------
function LuaShader:Compile()
	if not gl.CreateShader then
		self:ShowError("GLSL Shaders are not supported by hardware or drivers")
		return false
	end

	for _, shaderType in ipairs({"vertex", "tcs", "tes", "geometry", "fragment"}) do
		if self.shaderParams[shaderType] then
			local newShaderCode = LuaShader:HandleIncludes(self.shaderParams[shaderType], self.shaderName)
			if newShaderCode then
				self.shaderParams[shaderType] = newShaderCode
			end
		end
	end

	self.shaderObj = gl.CreateShader(self.shaderParams)
	local shaderObj = self.shaderObj

	local shLog = gl.GetShaderLog() or ""

	if not shaderObj then
		self:ShowError(shLog)
		return false
	elseif (shLog ~= "") then
		self:ShowWarning(shLog)
	end

	local uniforms = self.uniforms
	for idx, info in ipairs(gl.GetActiveUniforms(shaderObj)) do
		local uniName = string.gsub(info.name, "%[0%]", "") -- change array[0] to array
		uniforms[uniName] = {
			location = gl.GetUniformLocation(shaderObj, uniName),
			--type = info.type,
			--size = info.size,
			values = {},
		}
		--Spring.Echo(uniName, uniforms[uniName].location, uniforms[uniName].type, uniforms[uniName].size)
		--Spring.Echo(uniName, uniforms[uniName].location)
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
		return gl.UseShader(self.shaderObj)
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		self:ShowError(string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()", funcName))
		return false
	end
end

function LuaShader:ActivateWith(func, ...)
	if self.shaderObj ~= nil then
		self.active = true
		gl.ActiveShader(self.shaderObj, func, ...)
		self.active = false
	else
		local funcName = (debug and debug.getinfo(1).name) or "UnknownFunction"
		self:ShowError(string.format("Attempt to use invalid shader object in [%s](). Did you call :Compile() or :Initialize()", funcName))
	end
end

function LuaShader:Deactivate()
	self.active = false
	gl.UseShader(0)
end
-----------------============ End of general LuaShader methods ============-----------------


-----------------============ Friend LuaShader functions ============-----------------
local function getUniformLocation(self, name)
	local uniform = self.uniforms[name]

	if uniform and type(uniform) == "table" then
		return uniform
	elseif uniform == nil then --used for indexed elements. nil means not queried for location yet
		local location = gl.GetUniformLocation(self.shaderObj, name)
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
	if not self.active then
		self:ShowError(string.format("Trying to set uniform [%s] on inactive shader object. Did you use :Activate() or :ActivateWith()?", name))
		return nil
	end
	local uniform = getUniformLocation(self, name)
	if not uniform then
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
-----------------============ End of friend LuaShader functions ============-----------------


-----------------============ LuaShader uniform manipulation functions ============-----------------
-- TODO: do it safely with types, len, size check

--FLOAT UNIFORMS
local function setUniformAlwaysImpl(uniform, ...)
	gl.Uniform(uniform.location, ...)
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformAlways(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformAlwaysImpl(uniform, ...)
end

local function setUniformImpl(uniform, ...)
	if isUpdateRequired(uniform, {...}) then
		return setUniformAlwaysImpl(uniform, ...)
	end
	return true
end

function LuaShader:SetUniform(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformImpl(uniform, ...)
end

LuaShader.SetUniformFloat = LuaShader.SetUniform
LuaShader.SetUniformFloatAlways = LuaShader.SetUniformAlways


--INTEGER UNIFORMS
local function setUniformIntAlwaysImpl(uniform, ...)
	gl.UniformInt(uniform.location, ...)
	return true --currently there is no way to check if uniform is set or not :(
end

function LuaShader:SetUniformIntAlways(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntAlwaysImpl(uniform, ...)
end

local function setUniformIntImpl(uniform, ...)
	if isUpdateRequired(uniform, {...}) then
		return setUniformIntAlwaysImpl(uniform, ...)
	end
	return true
end

function LuaShader:SetUniformInt(name, ...)
	local uniform = getUniform(self, name)
	if not uniform then
		return false
	end
	return setUniformIntImpl(uniform, ...)
end


--FLOAT ARRAY UNIFORMS
local function setUniformFloatArrayAlwaysImpl(uniform, tbl)
	gl.UniformArray(uniform.location, UNIFORM_TYPE_FLOAT, tbl)
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
	gl.UniformArray(uniform.location, UNIFORM_TYPE_INT, tbl)
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
	gl.UniformMatrix(uniform.location, unpack(tbl))
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