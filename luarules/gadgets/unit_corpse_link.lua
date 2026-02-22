local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Corpse link",
		desc    = "Links corpses to their previous owner",
		author  = "SethDGamre",
		date    = "4 November 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		handler = true,
		enabled = not Engine.FeatureSupport.FeatureCreatedPassesSourceUnitID,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local CORPSE_LINK_TIMEOUT = Game.gameSpeed * 3 -- should be longer than the longest death animation
local UPDATE_INTERVAL = Game.gameSpeed

local corpseRegistryByDefID = {}

local function getPositionHash(x, z)
	return string.format("%f:%f", math.floor(x), math.floor(z))
end

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

	local x, y, z = Spring.GetFeaturePosition(featureID)
	local positionHash = getPositionHash(x, z)
	local corpseLink = unitDefLink[positionHash]
	if not corpseLink then
		return
	end

	corpseLink[positionHash] = nil
	return corpseLink.unitID
end

function gadget:UnitDestroyed(unitID, unitDefID)
	local unitDefLink = corpseRegistryByDefID[unitDefID]
	if not unitDefLink then
		unitDefLink = {}
		corpseRegistryByDefID[unitDefID] = unitDefLink
	end
	local x, y, z = Spring.GetUnitPosition(unitID)
	if not x then
		return
	end

	local positionHash = getPositionHash(x, z)
	unitDefLink[positionHash] = {
		unitID = unitID,
		timeout = Spring.GetGameFrame() + CORPSE_LINK_TIMEOUT
	}
end

function gadget:GameFrame(frame)
	if frame % UPDATE_INTERVAL ~= 0 then
		return
	end

	-- FIXME: could be sorted by timeout, so that we wouldn't have to iterate them all
	for unitDefID, unitDefLink in pairs(corpseRegistryByDefID) do
		for positionHash, corpseLink in pairs(unitDefLink) do
			if corpseLink.timeout < frame then
				unitDefLink[positionHash] = nil
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
		sourceID = sourceID or GG.GetCorpsePriorUnitID(featureID)
		originalFeatureCreated(self, featureID, allyTeam, sourceID)
	end
end

function gadget:Shutdown()
	gadgetHandler.FeatureCreated = originalFeatureCreated
end