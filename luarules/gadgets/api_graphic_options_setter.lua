function gadget:GetInfo()
	return {
		name      = "Graphical options setter",
		desc      = "Sets necessary spring configuration parameters, so shaded units look the way they should",
		author    = "ivand",
		date      = "2019",
		license   = "PD",
		layer     = -1,
		enabled   = true,
	}
end

if (not gadgetHandler:IsSyncedCode()) then --unsynced gadget
	function gadget:Initialize()
		Spring.SetConfigInt("CubeTexGenerateMipMaps", 1)
		Spring.SetConfigInt("CubeTexSizeReflection", 2048)
	end
end

