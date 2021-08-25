function gadget:GetInfo()
	return {
		name      = "Map TerrainTypes",
		version   = "v1",
		desc      = "Allows to disable terraintypes movespeed buffs",
		author    = "Doo",
		date      = "Nov 2017",
		license   = "GPL",
		layer     = -1,	--higher layer is loaded last
		enabled   = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		if not Spring.GetModOptions().map_terraintype then
			for i = 0 , 255 do
				if Spring.GetTerrainTypeData(i) then
					Spring.SetTerrainTypeData(i, 1, 1, 1, 1)
				end
			end
		end
		gadgetHandler:RemoveGadget(self)
	end
end
