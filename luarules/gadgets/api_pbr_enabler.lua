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
	local genLut

	local BRDFLUT_TEXDIM = 512 --512 is BRDF LUT texture resolution
	local BRDFLUT_GOPTION = 1

	local function GetBrdfTexture()
		return genLut:GetTexture()
	end

	function gadget:DrawGenesis()
		if genLut then
			genLut:Execute(false)
		end
		gadgetHandler:RemoveCallIn("DrawGenesis")
	end

	function gadget:Initialize()
		Spring.SetConfigInt("CubeTexGenerateMipMaps", 1)
		Spring.SetConfigInt("CubeTexSizeReflection", 1024)
		local genLutClass = VFS.Include("LuaRules/Gadgets/Include/GenBrdfLut.lua")
		if genLutClass then
			genLut = genLutClass(BRDFLUT_TEXDIM, BRDFLUT_GOPTION)
			if genLut then
				genLut:Initialize()
				GG.GetBrdfTexture = GetBrdfTexture
			end
		end
	end

	function gadget:Shutdown()
		if genLut then
			genLut:Finalize()
			GG.GetBrdfTexture = nil
		end
	end
end

