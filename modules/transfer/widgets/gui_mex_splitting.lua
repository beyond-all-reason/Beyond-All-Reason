local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mex Splitting",
		desc = "Under Map Assigned mex income: the map's regions in their holders' colours, pregame and whenever a mex is being placed",
		author = "BAR modules",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true,
	}
end

local TransferEnums = VFS.Include("modules/transfer/enums.lua")
if Spring.GetModOptions()[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.MapAssigned then
	return false
end

local Deal = VFS.Include("modules/transfer/mex_splitting/deal.lua") ---@type MexRegionsDealLib
local Shared = VFS.Include("modules/transfer/mex_splitting/shared.lua") ---@type MexRegionsShared
local Holders = VFS.Include("modules/transfer/mex_splitting/holders.lua") ---@type MexRegionsHolders

-- No deal by the time the UI loads means the match found no layout. If this player has drawn one for the map in the
-- terraformer, hand it to the gadget, which takes it only from a lone player before the start.
function widget:Initialize()
	if Spring.GetGameFrame() > 0 or Spring.GetGameRulesParam(Deal.PARAM) ~= nil then
		return
	end
	local Sources = VFS.Include("modules/transfer/mex_splitting/sources.lua") ---@type MexRegionSources
	local blob = Sources.EditorBlob(Game.mapName, Game.mapSizeX, Game.mapSizeZ)
	if blob then
		Spring.Echo("[Mex Splitting] offering this map's terraformer layout to the match")
		Spring.SendLuaRulesMsg(Shared.LAYOUT_MSG .. blob)
	end
end

local isMex = {} ---@type table<integer, boolean>
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = true
	end
end

local function placingAMex()
	local _, cmdID = Spring.GetActiveCommand()
	return cmdID ~= nil and (cmdID == GameCMD.AREA_MEX or (cmdID < 0 and isMex[-cmdID] == true))
end

---@param teamID integer
---@return string
local function holderName(teamID)
	local players = Spring.GetPlayerList(teamID)
	local name = players and players[1] and Spring.GetPlayerInfo(players[1], false) or nil
	return name or ("team " .. teamID)
end

-- The metal spots themselves say which are open to me: the game's own markers, coloured by construction's rule. This
-- widget only adds the why: over a spot an ally holds, while a mex is being placed, the game's tooltip says whose.
function widget:DrawScreenEffects()
	if not (placingAMex() and WG.tooltip and WG.tooltip.ShowTooltip) then
		return
	end
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	local finder = WG.resource_spot_finder
	local spot = pos and finder and finder.GetClosestMexSpot and finder.GetClosestMexSpot(pos[1], pos[3])
	if not spot or (spot.x - pos[1]) ^ 2 + (spot.z - pos[3]) ^ 2 > (Game.extractorRadius or 80) ^ 2 then
		return
	end
	local myTeamID = Spring.GetMyTeamID()
	local names = {}
	for _, holder in ipairs(Holders.At(Spring, spot.x, spot.z)) do
		if holder == myTeamID then
			return
		end
		if Spring.AreTeamsAllied(myTeamID, holder) then
			names[#names + 1] = holderName(holder)
		end
	end
	if #names > 0 then
		WG.tooltip.ShowTooltip(
			"mex_splitting",
			"This metal spot belongs to " .. table.concat(names, " and ") .. ": Mex Splitting is Map Assigned."
		)
	end
end
