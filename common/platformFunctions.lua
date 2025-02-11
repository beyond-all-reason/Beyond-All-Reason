if not Platform then return end
local hasGL4 = false
local hasGL = false
local hasShaders = false
local hasFBO = false
local isSyncedCode = (SendToUnsynced ~= nil)

local function determineCapabilities()
	if not gl then
		return
	end
	if Platform.glVendor ~= "" then
		hasGL = true
	end
	if gl.CreateShader and Platform.glHaveGLSL then
		hasShaders = true
	end
	if gl.CreateFBO then
		hasFBO = true
	end

	if hasFBO and hasShaders and Platform.glHaveGL4 then
		hasGL4 = true
	end
end

local function checkRequires(allRequires)
	if not allRequires or isSyncedCode then
		return true
	end
	for _, req in pairs(allRequires) do
		if req == 'gl' and not hasGL then
			return false
		elseif req == 'gl4' and not hasGL4 then
			return false
		elseif req == 'shaders' and not hasShaders then
			return false
		elseif req == 'fbo' and not hasFBO then
			return false
		end
	end
	return true
end

local function extendPlatform()
	Platform.gl = Platform.gl or hasGL
	Platform.gl4 = Platform.gl4 or hasGL4
	Platform.glHaveFBO = Platform.glHaveFBO or hasFBO
	Platform.check = checkRequires
end

determineCapabilities()
extendPlatform()
