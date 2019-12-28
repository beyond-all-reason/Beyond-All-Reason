function gadget:GetInfo()
	return {
		name      = "PBR enabler",
		desc      = "Generates BRDF Lookup table for PBR shaders and sets necessary spring configuration parameters",
		author    = "ivand",
		date      = "2019",
		license   = "PD",
		layer     = -1,
		enabled   = true,
	}
end

if (not gadgetHandler:IsSyncedCode()) then --unsynced gadget
	GG.GetBrdfTexture = nil
	GG.GetEnvTexture = nil

	if gl.CreateShader == nil then
		Spring.Echo("ERROR: PBR enabler: gl.CreateShader is nil")
		return
	end

	if gl.CreateFBO == nil then
		Spring.Echo("ERROR: PBR enabler: gl.CreateFBO is nil")
		return
	end

	local headless = Spring.GetConfigInt("Headless", 0) > 0
	if headless then
		return
	end

	local brdfLut = nil
	local envLut = nil

	local BRDFLUT_TEXDIM = 512 --512 is BRDF LUT texture resolution
	local BRDFLUT_GOPTION = 1

	local ENVLUT_SAMPLES -- number of cubemap samples

	local function GetBrdfTexture()
		return brdfLut:GetTexture()
	end

	local function GetEnvTexture()
		return envLut:GetTexture()
	end

	function gadget:DrawGenesis()
		if brdfLut then
			brdfLut:Execute(false)
		end
		gadgetHandler:RemoveCallIn("DrawGenesis")
	end

	local envLutDebug = false
	function gadget:DrawWorldPreUnit() --after IBL textures are rendered into, but before units are drawn
		if envLut then
			envLut:Execute(envLutDebug)
			if envLutDebug then
				envLutDebug = false
			end
		end
	end

	function gadget:Initialize()
		ENVLUT_SAMPLES = Spring.GetConfigInt("ENV_SMPL_NUM", 64)

		Spring.SetConfigInt("CubeTexGenerateMipMaps", 1)
		Spring.SetConfigInt("CubeTexSizeReflection", 1024)

		local brdfLutClass = VFS.Include("LuaRules/Gadgets/Include/GenBrdfLut.lua")
		if brdfLutClass then
			brdfLut = brdfLutClass(BRDFLUT_TEXDIM, BRDFLUT_GOPTION)
			if brdfLut then
				brdfLut:Initialize()
				GG.GetBrdfTexture = GetBrdfTexture
			end
		end

		local envLutClass = VFS.Include("LuaRules/Gadgets/Include/GenEnvLut.lua")
		if envLutClass then
			envLut = envLutClass(ENVLUT_SAMPLES)
			if envLut then
				envLut:Initialize()
				GG.GetEnvTexture = GetEnvTexture
			end
		end
	end

	function gadget:Shutdown()
		if brdfLut then
			brdfLut:Finalize()
			GG.GetBrdfTexture = nil
		end

		if envLut then
			envLut:Finalize()
			GG.GetEnvTexture = nil
		end
	end
end

