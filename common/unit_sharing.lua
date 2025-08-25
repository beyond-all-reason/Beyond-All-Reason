local sharing = {}

-- Cache for valid unit IDs by sharing mode
local validUnitCache = {}

function sharing.getUnitSharingMode()
	local mo = Spring.GetModOptions and Spring.GetModOptions()
	return (mo and mo.unit_sharing_mode) or "enabled"
end

function sharing.isT2ConstructorDef(unitDef)
	if not unitDef then return false end
	return (not unitDef.isFactory)
		and #(unitDef.buildOptions or {}) > 0
		and unitDef.customParams and unitDef.customParams.techlevel == "2"
end

function sharing.isEconomicUnitDef(unitDef)
	if not unitDef then return false end
	if unitDef.canAssist or unitDef.isFactory then
		return true
	end
	if unitDef.customParams and (unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal") then
		return true
	end
	return false
end

-- Lazy initialize the cache for a specific mode
local function ensureCacheInitialized(mode)
	if validUnitCache[mode] then
		return
	end
	
	if mode == "enabled" or mode == "disabled" then
		-- No need to cache for these modes
		validUnitCache[mode] = {}
		return
	end
	
	validUnitCache[mode] = {}
	local cachedCount = 0
	
	for unitDefID, unitDef in pairs(UnitDefs) do
		if mode == "t2cons" then
			-- Direct check for T2 constructor
			if sharing.isT2ConstructorDef(unitDef) then
				validUnitCache[mode][unitDefID] = true
				cachedCount = cachedCount + 1
			end
		elseif mode == "combat" then
			if not sharing.isEconomicUnitDef(unitDef) then
				validUnitCache[mode][unitDefID] = true
				cachedCount = cachedCount + 1
			end
		elseif mode == "combat_t2cons" then
			if not sharing.isEconomicUnitDef(unitDef) or sharing.isT2ConstructorDef(unitDef) then
				validUnitCache[mode][unitDefID] = true
				cachedCount = cachedCount + 1
			end
		end
	end
	
	Spring.Log("UnitSharing", LOG.INFO, "Lazy initialized cache for mode '" .. mode .. "' with " .. cachedCount .. " shareable units")
end

-- Clear the cache (useful if sharing mode changes)
function sharing.clearCache()
	validUnitCache = {}
end

-- Check if cache is initialized for a specific mode
function sharing.isCacheInitialized(mode)
	mode = mode or sharing.getUnitSharingMode()
	return validUnitCache[mode] ~= nil
end

-- Debug function to show cache statistics
function sharing.getCacheStats()
	local stats = {}
	for mode, cache in pairs(validUnitCache) do
		local count = 0
		for _ in pairs(cache) do
			count = count + 1
		end
		stats[mode] = count
	end
	return stats
end

function sharing.isUnitShareAllowedByMode(unitDefID, mode)
	mode = mode or sharing.getUnitSharingMode()
	if mode == "disabled" then
		return false
	elseif mode == "t2cons" or mode == "combat" or mode == "combat_t2cons" then
		ensureCacheInitialized(mode)
		return validUnitCache[mode][unitDefID] == true
	end
	return true
end

function sharing.countUnshareable(unitIDs, mode)
	mode = mode or sharing.getUnitSharingMode()
	local total = #unitIDs
	if mode == "enabled" then
		return total, 0, total
	elseif mode == "disabled" then
		return 0, total, total
	end
	
	ensureCacheInitialized(mode)
	
	local shareable = 0
	for i = 1, total do
		local udid = Spring.GetUnitDefID(unitIDs[i])
		if udid and validUnitCache[mode][udid] then
			shareable = shareable + 1
		end
	end
	return shareable, (total - shareable), total
end

function sharing.shouldShowShareButton(unitIDs, mode)
	mode = mode or sharing.getUnitSharingMode()
	if mode == "disabled" then return false end
	local shareable, _, total = sharing.countUnshareable(unitIDs, mode)
	local result = total > 0 and shareable > 0
	return result
end

function sharing.blockMessage(unshareable, mode)
	mode = mode or sharing.getUnitSharingMode()
	if mode == "disabled" then
		return "Unit sharing is disabled"
	elseif mode == "t2cons" then
		return "Attempted to share " .. tostring(unshareable or 0) .. " unshareable units. Share mode is T2 constructors only"
	elseif mode == "combat" then
		return "Attempted to share " .. tostring(unshareable or 0) .. " economic units. Share mode is combat units only"
	elseif mode == "combat_t2cons" then
		return "Attempted to share " .. tostring(unshareable or 0) .. " unshareable units. Share mode is combat units and T2 constructors only"
	end
	return nil
end

return sharing


