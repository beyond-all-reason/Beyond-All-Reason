local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local TransferEnums = VFS.Include("modules/sharing/enums.lua")
local PolicyShared = VFS.Include("modules/sharing/serialization.lua")
local UnitSharingCategories = VFS.Include("modules/sharing/unit/categories.lua")
local Comms = VFS.Include("modules/sharing/unit/comms.lua")

local Shared = Comms

local FieldTypes = PolicyShared.FieldTypes
Shared.UnitPolicyFields = {
	canShare = FieldTypes.boolean,
	sharingModes = FieldTypes.string,
	-- carried to the widget so the share tooltip can surface the share-time effects
	buildDelaySeconds = FieldTypes.number,
	stunSeconds = FieldTypes.number,
	stunCategory = FieldTypes.string,
}

-- cached per-team factors; GetCachedPolicyResult rebuilds any pair on read (alliance + active stay live)
Shared.UnitFactorFields = {
	sharingModes = FieldTypes.string,
	active = FieldTypes.boolean,
}

---Rules-param key for a team's unit factor record (owner team = the rules-param team).
---@return string
function Shared.MakeFactorKey()
	return TransferEnums.PolicyType.UnitTransfer .. "_factor"
end

---@param factor table {sharingModes: string[], active: boolean}
---@return string
function Shared.SerializeUnitFactor(factor)
	return PolicyShared.Serialize(Shared.UnitFactorFields, {
		sharingModes = table.concat(factor.sharingModes or { ModeEnums.UnitFilterCategory.None }, ","),
		active = factor.active,
	})
end

---@param serialized string
---@return table {sharingModes: string[], active: boolean}
function Shared.DeserializeUnitFactor(serialized)
	local raw = PolicyShared.Deserialize(Shared.UnitFactorFields, serialized)
	local modes = {}
	for m in (raw.sharingModes or "none"):gmatch("[^,]+") do
		modes[#modes + 1] = m
	end
	return { sharingModes = modes, active = raw.active }
end

local allUnitTypes = {
	TransferEnums.UnitType.Combat,
	TransferEnums.UnitType.Commander,
	TransferEnums.UnitType.Constructor,
	TransferEnums.UnitType.Factory,
	TransferEnums.UnitType.Resource,
	TransferEnums.UnitType.Utility,
}

function Shared.GetModeUnitTypes(category)
	if category == ModeEnums.UnitFilterCategory.None then
		return {}
	end

	if category == ModeEnums.UnitFilterCategory.All then
		return allUnitTypes
	end

	if category == ModeEnums.UnitFilterCategory.Combat then
		return { TransferEnums.UnitType.Combat, TransferEnums.UnitType.Commander }
	end

	if category == ModeEnums.UnitFilterCategory.Buildings then
		return { TransferEnums.UnitType.Factory, TransferEnums.UnitType.Resource, TransferEnums.UnitType.Utility }
	end

	if category == ModeEnums.UnitFilterCategory.Constructors then
		return { TransferEnums.UnitType.Constructor }
	end

	if category == ModeEnums.UnitFilterCategory.Resource then
		return { TransferEnums.UnitType.Resource }
	end

	if category == ModeEnums.UnitFilterCategory.NonCombat then
		return {
			TransferEnums.UnitType.Constructor,
			TransferEnums.UnitType.Factory,
			TransferEnums.UnitType.Resource,
			TransferEnums.UnitType.Utility,
		}
	end

	return {}
end

local function UnitTypeMatchesCategory(unitDef, category)
	local unitType = UnitSharingCategories.classifyUnitDef(unitDef)
	local categoryUnitTypes = Shared.GetModeUnitTypes(category)
	return table.contains(categoryUnitTypes, unitType)
end

---@param unitDef table
---@param category string
---@return boolean
local function EvaluateUnitForSharing(unitDef, category)
	if not unitDef then
		return false
	end

	if category == ModeEnums.UnitFilterCategory.None then
		return false
	end

	if category == ModeEnums.UnitFilterCategory.All then
		return true
	end

	return UnitTypeMatchesCategory(unitDef, category)
end

-- Keyed by the defs table (UnitDefs in practice, so at most a few entries).
-- Plain table, not weak-keyed: restricted include environments (the test
-- runner sandbox, synced chunks) don't expose setmetatable.
local allowedByCategory = {}

local function BuildAllowedCacheForCategory(category, unitDefs)
	local defs = unitDefs or UnitDefs
	if not defs then
		return nil
	end
	local cacheByDefs = allowedByCategory[defs]
	if not cacheByDefs then
		cacheByDefs = {}
		allowedByCategory[defs] = cacheByDefs
	end
	if cacheByDefs[category] then
		return cacheByDefs[category]
	end
	local cache = {}
	for unitDefID, unitDef in pairs(defs) do
		if EvaluateUnitForSharing(unitDef, category) then
			cache[unitDefID] = true
		end
	end
	cacheByDefs[category] = cache
	return cache
end

---@param unitDefId number
---@param categories string|string[]
---@param unitDefs table?
---@return boolean
function Shared.IsShareableDef(unitDefId, categories, unitDefs)
	if not unitDefId or not categories then
		return false
	end
	if type(categories) == "string" then
		categories = { categories }
	end
	for _, category in ipairs(categories) do
		if category == ModeEnums.UnitFilterCategory.All then
			return true
		end
		local cache = BuildAllowedCacheForCategory(category, unitDefs)
		if cache and cache[unitDefId] then
			return true
		end
	end
	return false
end

return Shared
