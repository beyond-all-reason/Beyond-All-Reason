local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Corpse link",
		desc = "Links corpses to their previous owner",
		author = "SethDGamre",
		date = "4 November 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		handler = true,
		-- Stay enabled as a fallback when the engine omits sourceID (e.g. death anim moved the wreck).
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local CORPSE_LINK_TIMEOUT = Game.gameSpeed * 3 -- should be longer than the longest death animation
local UPDATE_INTERVAL = Game.gameSpeed

-- unitDefID -> { [unitID] = { x, z, timeout } }
local corpseRegistryByDefID = {}

local function GetFeatureResurrectDefID(featureID)
	local resurrectUnitName = Spring.GetFeatureResurrect(featureID)
	if not resurrectUnitName then
		return
	end

	local unitDef = UnitDefNames[resurrectUnitName]
	if not unitDef then
		return
	end

	return unitDef.id
end

local function GetCorpsePriorUnitID(featureID)
	-- Technically features can rez into something else than they died as,
	-- or even be rezzable without ever dying, but let's assume they don't
	local resurrectUnitDefID = GetFeatureResurrectDefID(featureID)

	local unitDefLink = corpseRegistryByDefID[resurrectUnitDefID]
	if not unitDefLink then
		return
	end

	local x, _, z = Spring.GetFeaturePosition(featureID)
	if not x then
		return
	end

	-- Snap to the closest pending death of this unitDef. Exact-position matching
	-- breaks when death animations carry the wreck away from UnitDestroyed coords.
	local bestUnitID
	local bestDistSq
	for unitID, corpseLink in pairs(unitDefLink) do
		local dx = corpseLink.x - x
		local dz = corpseLink.z - z
		local distSq = dx * dx + dz * dz
		if bestDistSq == nil or distSq < bestDistSq then
			bestDistSq = distSq
			bestUnitID = unitID
		end
	end

	if not bestUnitID then
		return
	end

	unitDefLink[bestUnitID] = nil
	return bestUnitID
end

local function ConsumeCorpseLink(unitID)
	for _, unitDefLink in pairs(corpseRegistryByDefID) do
		if unitDefLink[unitID] then
			unitDefLink[unitID] = nil
			return
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID)
	local unitDefLink = corpseRegistryByDefID[unitDefID]
	if not unitDefLink then
		unitDefLink = {}
		corpseRegistryByDefID[unitDefID] = unitDefLink
	end
	local x, _, z = Spring.GetUnitPosition(unitID)
	if not x then
		return
	end

	unitDefLink[unitID] = {
		x = x,
		z = z,
		timeout = Spring.GetGameFrame() + CORPSE_LINK_TIMEOUT,
	}
end

function gadget:GameFrame(frame)
	if frame % UPDATE_INTERVAL ~= 0 then
		return
	end

	-- FIXME: could be sorted by timeout, so that we wouldn't have to iterate them all
	for _, unitDefLink in pairs(corpseRegistryByDefID) do
		for unitID, corpseLink in pairs(unitDefLink) do
			if corpseLink.timeout < frame then
				unitDefLink[unitID] = nil
			end
		end
	end
end

local originalFeatureCreated

function gadget:Initialize()
	-- Expose GetPriorUnitID globally for other gadgets/widgets to use
	GG.GetCorpsePriorUnitID = GetCorpsePriorUnitID

	originalFeatureCreated = gadgetHandler.FeatureCreated
	gadgetHandler.FeatureCreated = function(self, featureID, allyTeam, sourceID)
		if sourceID then
			-- Engine already linked this wreck; drop our fallback entry so it
			-- cannot be snapped to by a later feature.
			ConsumeCorpseLink(sourceID)
		else
			sourceID = GG.GetCorpsePriorUnitID(featureID)
		end
		originalFeatureCreated(self, featureID, allyTeam, sourceID)
	end
end

function gadget:Shutdown()
	gadgetHandler.FeatureCreated = originalFeatureCreated
end
