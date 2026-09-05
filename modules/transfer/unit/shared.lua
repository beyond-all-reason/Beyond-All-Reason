local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local UnitCategories = VFS.Include("modules/construction/lib/unit_categories.lua")
local PolicyShared = VFS.Include("modules/transfer/lib/serialization.lua")
local UnitSharingCategories = VFS.Include("modules/transfer/unit/categories.lua")
local Comms = VFS.Include("modules/transfer/unit/comms.lua")

local Shared = Comms

local FieldTypes = PolicyShared.FieldTypes
Shared.UnitPolicyFields = {
	canShare = FieldTypes.boolean,
	sharingModes = FieldTypes.string,
	buildDelaySeconds = FieldTypes.number,
	stunSeconds = FieldTypes.number,
	stunCategory = FieldTypes.string,
}

Shared.UnitFactorFields = {
	sharingModes = FieldTypes.string,
	active = FieldTypes.boolean,
}

---@return string
function Shared.MakeFactorKey()
	return TransferEnums.PolicyType.UnitTransfer .. "_factor"
end

---@param factor table {sharingModes: string[], active: boolean}
---@return string
function Shared.SerializeUnitFactor(factor)
	return PolicyShared.Serialize(Shared.UnitFactorFields, {
		sharingModes = table.concat(factor.sharingModes or { ConstructionEnums.UnitFilterCategory.None }, ","),
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

---@param unitDefID integer
---@param stunCategory string?
---@param defs table
---@return boolean
local function wouldBeStunned(unitDefID, stunCategory, defs)
	if not stunCategory then
		return false
	end
	return Shared.IsShareableDef(unitDefID, stunCategory, defs)
end

---@param arr table
local function resetArray(arr)
	for i = #arr, 1, -1 do
		arr[i] = nil
	end
end

---@param policyResult UnitPolicyResult
---@param unitIds integer[]
---@param springApi Spring?
---@param unitDefs table?
---@param out UnitValidationResult? optional pre-allocated result to fill in place (table lifting)
---@return UnitValidationResult
function Shared.ValidateUnits(policyResult, unitIds, springApi, unitDefs, out)
	local spring = springApi or Spring
	local defs = unitDefs or UnitDefs or (spring.GetUnitDefs and spring.GetUnitDefs()) or {}

	-- arrays cleared rather than replaced so stale entries never leak into a reused table
	out = out or {} --[[@as UnitValidationResult]]
	out.status = TransferEnums.UnitValidationOutcome.Failure
	out.validUnitCount = 0
	out.invalidUnitCount = 0
	out.buildDelayedUnitCount = 0
	out.stunnedUnitCount = 0
	out.validUnitNames = out.validUnitNames or {}
	out.validUnitIds = out.validUnitIds or {}
	out.invalidUnitNames = out.invalidUnitNames or {}
	out.invalidUnitIds = out.invalidUnitIds or {}
	resetArray(out.validUnitNames)
	resetArray(out.validUnitIds)
	resetArray(out.invalidUnitNames)
	resetArray(out.invalidUnitIds)

	if (not policyResult.canShare) or (not unitIds or #unitIds == 0) then
		return out
	end

	local modes = policyResult.sharingModes or { "none" }
	local stunSeconds = tonumber(policyResult.stunSeconds) or 0
	local stunCategory = policyResult.stunCategory

	-- dedupe sets stay call-local; a shared one would leak keys across rotating `out` tables
	local validUnitNamesSet = {} ---@type table<string, boolean>
	local invalidUnitNamesSet = {} ---@type table<string, boolean>
	for _, unitId in ipairs(unitIds) do
		local unitDefID = spring.GetUnitDefID(unitId)
		if not unitDefID then
			-- LOG.ERROR must stay numeric: the engine rejects numeric *strings* as log levels
			spring.Log("unit_transfer_shared", LOG.ERROR, string.format("ValidateUnits: unitId %d not found", unitId))
			out.invalidUnitCount = out.invalidUnitCount + 1
			table.insert(out.invalidUnitIds, unitId)
			if not invalidUnitNamesSet["Unknown Unit"] then
				invalidUnitNamesSet["Unknown Unit"] = true
				table.insert(out.invalidUnitNames, "Unknown Unit")
			end
		else
			local ok = Shared.IsShareableDef(unitDefID, modes, defs)
			local def = defs[unitDefID] or defs[tostring(unitDefID)]
			local unitName = (def and (def.translatedHumanName or def.name)) or tostring(unitDefID)

			-- nanoframes of stun-category units would bypass the tax
			if ok and stunSeconds > 0 and wouldBeStunned(unitDefID, stunCategory, defs) then
				local beingBuilt, buildProgress = spring.GetUnitIsBeingBuilt(unitId)
				if beingBuilt and buildProgress > 0 then
					ok = false
				end
			end

			if ok then
				out.validUnitCount = out.validUnitCount + 1
				table.insert(out.validUnitIds, unitId)
				if UnitSharingCategories.isMobileBuilderDef(def) then
					out.buildDelayedUnitCount = out.buildDelayedUnitCount + 1
				end
				if wouldBeStunned(unitDefID, stunCategory, defs) then
					out.stunnedUnitCount = out.stunnedUnitCount + 1
				end
				if not validUnitNamesSet[unitName] then
					validUnitNamesSet[unitName] = true
					table.insert(out.validUnitNames, unitName)
				end
			else
				out.invalidUnitCount = out.invalidUnitCount + 1
				table.insert(out.invalidUnitIds, unitId)
				if not invalidUnitNamesSet[unitName] then
					invalidUnitNamesSet[unitName] = true
					table.insert(out.invalidUnitNames, unitName)
				end
			end
		end
	end

	if out.validUnitCount > 0 and out.invalidUnitCount == 0 then
		out.status = TransferEnums.UnitValidationOutcome.Success
	elseif out.validUnitCount > 0 and out.invalidUnitCount > 0 then
		out.status = TransferEnums.UnitValidationOutcome.PartialSuccess
	else
		out.status = TransferEnums.UnitValidationOutcome.Failure
	end

	return out
end

---@param senderTeamId integer
---@param receiverTeamId integer
---@param springApi Spring?
---@return UnitPolicyResult
function Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId, springApi)
	local spring = springApi or Spring
	local modOptions = spring.GetModOptions()
	local stunSeconds = tonumber(modOptions[TransferEnums.ModOptions.UnitShareStunSeconds]) or 0
	local stunCategory = modOptions[TransferEnums.ModOptions.UnitStunCategory]
		or ConstructionEnums.UnitFilterCategory.Resource
	local buildDelaySeconds = tonumber(modOptions[ConstructionEnums.ModOptions.ConstructorBuildDelay]) or 0

	local areAllied = (spring.AreTeamsAllied and spring.AreTeamsAllied(senderTeamId, receiverTeamId)) == true

	local factorKey = Shared.MakeFactorKey()
	local senderSerialized = spring.GetTeamRulesParam(senderTeamId, factorKey)
	local receiverSerialized = spring.GetTeamRulesParam(receiverTeamId, factorKey)

	if senderSerialized == nil or receiverSerialized == nil then
		local category = modOptions.unit_sharing_mode or ConstructionEnums.UnitFilterCategory.None
		---@type UnitPolicyResult
		return {
			senderTeamId = senderTeamId,
			receiverTeamId = receiverTeamId,
			canShare = areAllied and category ~= ConstructionEnums.UnitFilterCategory.None,
			sharingModes = { category },
			stunSeconds = stunSeconds,
			stunCategory = stunCategory,
			buildDelaySeconds = buildDelaySeconds,
		}
	end

	local senderFactor = Shared.DeserializeUnitFactor(senderSerialized)
	local receiverFactor = Shared.DeserializeUnitFactor(receiverSerialized)
	local modes = senderFactor.sharingModes
	local modeNotNone = not (#modes == 1 and modes[1] == ConstructionEnums.UnitFilterCategory.None)

	local canShare = areAllied and modeNotNone
	if canShare and not (spring.IsCheatingEnabled and spring.IsCheatingEnabled()) then
		if not receiverFactor.active then
			canShare = false
		end
	end

	---@type UnitPolicyResult
	return {
		senderTeamId = senderTeamId,
		receiverTeamId = receiverTeamId,
		canShare = canShare,
		sharingModes = modes,
		stunSeconds = stunSeconds,
		stunCategory = stunCategory,
		buildDelaySeconds = buildDelaySeconds,
	}
end

function Shared.GetModeUnitTypes(category)
	return UnitCategories.TypesFor(category)
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

	if category == ConstructionEnums.UnitFilterCategory.None then
		return false
	end

	if category == ConstructionEnums.UnitFilterCategory.All then
		return true
	end

	return UnitTypeMatchesCategory(unitDef, category)
end

local allowedByCategory = setmetatable({}, { __mode = "k" })

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
		if category == ConstructionEnums.UnitFilterCategory.All then
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
