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

if gadgetHandler:IsSyncedCode() then

	local waterlevel = Spring.GetModOptions().map_waterlevel

	local function isAuthorized(playerID)
		if Spring.IsCheatingEnabled() then
			return true
		end
		local _, _, _, _, _, _, _, _, _, _, accountInfo = Spring.GetPlayerInfo(playerID)
		local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
		return _G.permissions and _G.permissions.waterlevel and _G.permissions.waterlevel[accountID] or false
	end

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

	local function handleWaterlevel(_cmd, _line, words, playerID)
		if not isAuthorized(playerID) then return end
		local val = tonumber(words[1])
		if not val then return end
		waterlevel = val
		adjustWaterlevel()
		Spring.Echo('Changed waterlevel: ' .. waterlevel)
	end

	local function handleClampMinHeight(_cmd, _line, words, playerID)
		if not isAuthorized(playerID) then return end
		local minH = tonumber(words[1])
		if not minH then return end
		Spring.SetHeightMapFunc(function()
			local sq = Game.squareSize
			for x = 0, Game.mapSizeX, sq do
				for z = 0, Game.mapSizeZ, sq do
					local h = Spring.GetGroundHeight(x, z)
					if h < minH then
						Spring.SetHeightMap(x, z, minH)
					end
				end
			end
		end)
		adjustFeatureHeight()
		Spring.Echo('Clamped map min height to: ' .. minH)
	end

	local function handleClampMaxHeight(_cmd, _line, words, playerID)
		if not isAuthorized(playerID) then return end
		local maxH = tonumber(words[1])
		if not maxH then return end
		Spring.SetHeightMapFunc(function()
			local sq = Game.squareSize
			for x = 0, Game.mapSizeX, sq do
				for z = 0, Game.mapSizeZ, sq do
					local h = Spring.GetGroundHeight(x, z)
					if h > maxH then
						Spring.SetHeightMap(x, z, maxH)
					end
				end
			end
		end)
		adjustFeatureHeight()
		Spring.Echo('Clamped map max height to: ' .. maxH)
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

		gadgetHandler:AddChatAction('waterlevel', handleWaterlevel)
		gadgetHandler:AddChatAction('clampminheight', handleClampMinHeight)
		gadgetHandler:AddChatAction('clampmaxheight', handleClampMaxHeight)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('waterlevel')
		gadgetHandler:RemoveChatAction('clampminheight')
		gadgetHandler:RemoveChatAction('clampmaxheight')
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
end
