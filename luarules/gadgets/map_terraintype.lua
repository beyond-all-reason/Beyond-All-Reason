--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

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


if (gadgetHandler:IsSyncedCode()) then


function gadget:Initialize()
TerrainTypeTable = {}
	if Spring.GetModOptions() and Spring.GetModOptions().map_terraintype and Spring.GetModOptions().map_terraintype == "disabled" then
		for i = 0 , 255 do
			if Spring.GetTerrainTypeData(i) then
				TerrainTypeTable[i] = {Spring.GetTerrainTypeData(i)}
				Spring.SetTerrainTypeData(i, 1, 1, 1, 1)
			end
		end
	end
end
end


