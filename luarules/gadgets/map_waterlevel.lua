--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Map Waterlevel",
		version = "v1",
		desc = "Implements map_waterlevel modoption or enable cheats and do /luarules waterlevel #",
		author = "Doo",
		date = "Nov 2017",
		license = "GNU GPL, v2 or later",
		layer = 999999, --higher layer is loaded last
		enabled = true,
	}
end

local PACKET_HEADER = "$wl$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

if gadgetHandler:IsSyncedCode() then

	local waterlevel = Spring.GetModOptions().map_waterlevel

	function adjustFeatureHeight()
		local featuretable = Spring.GetAllFeatures()
		local x, y, z
		for i = 1, #featuretable do
			x, y, z = Spring.GetFeaturePosition(featuretable[i])
      		Spring.SetFeaturePosition(featuretable[i], x,  y,  z ,true) -- snaptoground = true
		end
	end

	function adjustWaterlevel()
		-- Spring.SetMapRenderingParams({ voidWater = false})
    	Spring.Echo("Map Waterlevel: adjusting water level with: "..waterlevel)
		Spring.AdjustHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
		Spring.AdjustOriginalHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
		Spring.AdjustSmoothMesh(0, 0, Game.mapSizeX, Game.mapSizeZ, -waterlevel)
		adjustFeatureHeight()
	end

	function gadget:Initialize()
		if Spring.GetGameFrame() == 0 then
			local modOptions = Spring.GetModOptions()
			if modOptions.map_waterlevel ~= 0 then
				waterlevel = modOptions.map_waterlevel

				-- adjust tidal strength if previosuly not present and applicable
				if (modOptions.map_tidal == nil or modOptions.map_tidal == "unchanged")
					and Spring.GetTidal() == 0
					and select(1, Spring.GetGroundExtremes()) > 0
					then
						Spring.SetTidal( 15 )
				end

				adjustWaterlevel()
			end
		end
	end

	function gadget:GameFrame(gf)
		-- Keeping this in forces feature recreation on frame 0, with a lag spike on init, also destroying all preexisting feature rotations.
		-- adjustFeatureHeight() -- im removing this, this is stupid. B.
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

		local accountInfo = select(11, Spring.GetPlayerInfo(playerID,false))
		local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
		local authorized = _G.permissions.waterlevel[accountID]

		if not (authorized or Spring.IsCheatingEnabled()) then
			return
		end

		local params = string.split(msg, ':')
		waterlevel = tonumber(params[2])
		adjustWaterlevel()
		Spring.Echo('Changed waterlevel: ' .. waterlevel)
	end

else  -- UNSYNCED

	local myPlayerID = Spring.GetMyPlayerID()
	local accountInfo = select(11, Spring.GetPlayerInfo(myPlayerID,false))
	local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
	local authorized = SYNCED.permissions.waterlevel[accountID]

	local function waterlevel(cmd, line, words, playerID)
		if words[1] then
			if (authorized or Spring.IsCheatingEnabled()) and playerID == myPlayerID then
				Spring.SendLuaRulesMsg(PACKET_HEADER .. ':' .. words[1])
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction('waterlevel', waterlevel)
	end
	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('waterlevel')
	end
end
