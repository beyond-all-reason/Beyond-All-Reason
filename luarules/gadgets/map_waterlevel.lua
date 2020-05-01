--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Map Waterlevel",
		version   = "v1",
		desc      = "Sets map waterlevel according to the modoption",
		author    = "Doo",
		date      = "Nov 2017",
		license   = "GPL",
		layer     = math.huge,	--higher layer is loaded last
		enabled   = true,
	}
end

local PACKET_HEADER = "$wl$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

if (gadgetHandler:IsSyncedCode()) then

	local waterlevel = ((Spring.GetModOptions() and tonumber(Spring.GetModOptions().map_waterlevel)) or 0)

	function explode(div,str) -- credit: http://richard.warburton.it
		if (div=='') then return false end
		local pos,arr = 0,{}
		-- for each divider found
		for st,sp in function() return string.find(str,div,pos,true) end do
			table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
			pos = sp + 1 -- Jump past current divider
		end
		table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
		return arr
	end

	function adjustWaterlevel()
		-- Spring.SetMapRenderingParams({ voidWater = false})
		Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
		Spring.AdjustSmoothMesh(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
	end

	function waterlevel()
		if not Spring.IsCheatingEnabled() then return end

	end

	function gadget:Initialize()
		if Spring.GetGameFrame() == 0 and Spring.GetModOptions() and Spring.GetModOptions().map_waterlevel and Spring.GetModOptions().map_waterlevel ~= "0" then
			adjustWaterlevel()
		end
	end

	function gadget:GamePreload()
		if Spring.GetModOptions() and Spring.GetModOptions().map_waterlevel and Spring.GetModOptions().map_waterlevel ~= "0" then --only move features if there was a waterlevel change
			featuretable = Spring.GetAllFeatures()
			for i = 1,#featuretable do
				featureDefID = Spring.GetFeatureDefID(featuretable[i])
				x,_,z = Spring.GetFeaturePosition(featuretable[i])
				Spring.DestroyFeature(featuretable[i])
				if (Spring.GetGroundHeight(x,z) >= 0) or (FeatureDefs[featureDefID].geoThermal == true) or (FeatureDefs[featureDefID].metal > 0) then -- Keep features (> 0 height) or (geovents) or (contains metal)
					Spring.CreateFeature(featureDefID, x, Spring.GetGroundHeight(x,z), z)
				end
			end
		end
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if not Spring.IsCheatingEnabled() then return end
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end
		local params = explode(':', msg)
		waterlevel = tonumber(params[2])
		adjustWaterlevel()
		Spring.Echo('Changed waterlevel: '..waterlevel)
	end

else	-- UNSYNCED

	function gadget:Initialize()
		gadgetHandler:AddChatAction('waterlevel', waterlevel)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('waterlevel')
	end

	function waterlevel(cmd, line, words, playerID)
		if not Spring.IsCheatingEnabled() then
			Spring.Echo('Changing waterlevel requires cheats')
			return
		end
		if words[1] then
			Spring.SendLuaRulesMsg(PACKET_HEADER..':'..words[1])
		end
	end
end
