--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Map Waterlevel",
		version   = "v1",
		desc      = "Implements map_waterlevel modoption or enable cheats and do /luarules waterlevel #",
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

	local authorizedPlayers  = {
		'Floris',
		'[teh]Flow',
		'IceXuick',
	}

	local waterlevel = ((Spring.GetModOptions() and tonumber(Spring.GetModOptions().map_waterlevel)) or 0)
	local orgFeaturePosY = {}

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

	function adjustFeatureHeight()
		local featuretable = Spring.GetAllFeatures()
		local x,y,z,rx,ry,rz,featureDefID
		for i = 1,#featuretable do
			if not orgFeaturePosY[i] then
				orgFeaturePosY[i] = select(2, Spring.GetFeaturePosition(featuretable[i]))
			end
			x,y,z = Spring.GetFeaturePosition(featuretable[i])
      if math.abs(Spring.GetGroundHeight(x,z) - y) > 0.01 then
        --Spring.Echo("Feature position wrong (",x,y,z,")", Spring.GetGroundHeight(x,z), orgFeaturePosY[i])

        featureDefID = Spring.GetFeatureDefID(featuretable[i])

        rx,ry,rz = Spring.GetFeatureRotation(featuretable[i])
        Spring.DestroyFeature(featuretable[i])
        if Spring.GetGroundHeight(x,z) >= 0 or FeatureDefs[featureDefID].geoThermal == true or FeatureDefs[featureDefID].metal > 0 then -- Keep features (> 0 height) or (geovents) or (contains metal)
          y = orgFeaturePosY[i] - waterlevel --Spring.GetGroundHeight(x,z)
          local newfeatureID = Spring.CreateFeature(featureDefID, x,y,z)
          Spring.SetFeatureRotation(newfeatureID, rx,ry,rz)
        end
      end
		end
	end

	function adjustWaterlevel()
		-- Spring.SetMapRenderingParams({ voidWater = false})
		Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
		Spring.AdjustSmoothMesh(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
		adjustFeatureHeight()
	end

	function gadget:Initialize()
		if Spring.GetGameFrame() == 0 and Spring.GetModOptions() and Spring.GetModOptions().map_waterlevel and tonumber(Spring.GetModOptions().map_waterlevel) ~= 0 then
      --Spring.Echo("gadget:Initialize() : Spring.GetModOptions().map_waterlevel",Spring.GetModOptions().map_waterlevel)
			waterlevel = ((Spring.GetModOptions() and tonumber(Spring.GetModOptions().map_waterlevel)))
			adjustWaterlevel()
		end
	end

	function gadget:GameFrame(gf) -- Keeping this in forces feature recreation on frame 0, with a lag spike on init, also destroying all preexisting feature rotations.
		adjustFeatureHeight()
		gadgetHandler:RemoveCallIn("GameFrame")
	end

	function gadget:GamePreload()
		if waterlevel ~= 0 then
			adjustFeatureHeight()
		end
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end

		local playername, _, spec = Spring.GetPlayerInfo(playerID,false)
		local authorized = false
		for _,name in ipairs(authorizedPlayers) do
			if playername == name then
				authorized = true
				givenSomethingAtFrame = Spring.GetGameFrame()
				break
			end
		end

		if not authorized or not Spring.IsCheatingEnabled() then return end

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
		--if not Spring.IsCheatingEnabled() then
		--	Spring.Echo('Changing waterlevel requires cheats')
		--	return
		--end
		if words[1] then
			Spring.SendLuaRulesMsg(PACKET_HEADER..':'..words[1])
		end
	end
end
