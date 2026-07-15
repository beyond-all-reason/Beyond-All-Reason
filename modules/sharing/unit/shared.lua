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

---clear an array in place so a lifted result table can be reused without churning garbage
---@param arr table
local function resetArray(arr)
	for i = #arr, 1, -1 do
		arr[i] = nil
	end
end

---Validate a list of unitIds under current mode
---@param policyResult UnitPolicyResult
---@param unitIds integer[]
---@param springApi EngineSynced?
---@param unitDefs table?
---@param out UnitValidationResult? optional pre-allocated result to fill in place (table lifting)
---@return UnitValidationResult
function Shared.ValidateUnits(policyResult, unitIds, springApi, unitDefs, out)
	local spring = springApi or Spring
	local defs = unitDefs or UnitDefs or (spring.GetUnitDefs and spring.GetUnitDefs()) or {}

	-- reuse caller's table when supplied; scalars reassigned and arrays cleared so stale entries never leak
	out = out or ({} --[[@as UnitValidationResult]]) -- every field is (re)assigned below
	out.status = TransferEnums.UnitValidationOutcome.Failure
	out.validUnitCount = 0
	out.invalidUnitCount = 0
	out.buildDelayedUnitCount = 0 -- valid units that will receive the constructor build delay
	out.stunnedUnitCount = 0 -- valid units that will be stunned (stun category)
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

			-- Block nanoframes for units that would be stunned (prevents tax bypass)
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

---rebuild (sender,receiver) unit policy from cached factors + live gates (mirrors Synced.GetPolicy); missing factors fall back to global unit_sharing_mode
---@param senderTeamId integer
---@param receiverTeamId integer
---@param springApi EngineSynced?
---@return UnitPolicyResult
function Shared.GetCachedPolicyResult(senderTeamId, receiverTeamId, springApi)
	local spring = springApi or Spring
	local modOptions = spring.GetModOptions()
	local stunSeconds = tonumber(modOptions[ModeEnums.ModOptions.UnitShareStunSeconds]) or 0
	local stunCategory = modOptions[ModeEnums.ModOptions.UnitStunCategory] or ModeEnums.UnitFilterCategory.Resource
	local buildDelaySeconds = tonumber(modOptions[ModeEnums.ModOptions.ConstructorBuildDelay]) or 0

	local areAllied = (spring.AreTeamsAllied and spring.AreTeamsAllied(senderTeamId, receiverTeamId)) == true

	local factorKey = Shared.MakeFactorKey()
	local senderSerialized = spring.GetTeamRulesParam(senderTeamId, factorKey)
	local receiverSerialized = spring.GetTeamRulesParam(receiverTeamId, factorKey)

	if senderSerialized == nil or receiverSerialized == nil then
		-- Pre-cache fallback: global mode + alliance only (matches legacy behaviour).
		local category = modOptions.unit_sharing_mode or ModeEnums.UnitFilterCategory.None
		---@type UnitPolicyResult
		return {
			senderTeamId = senderTeamId,
			receiverTeamId = receiverTeamId,
			canShare = areAllied and category ~= ModeEnums.UnitFilterCategory.None,
			sharingModes = { category },
			stunSeconds = stunSeconds,
			stunCategory = stunCategory,
			buildDelaySeconds = buildDelaySeconds,
		}
	end

	local senderFactor = Shared.DeserializeUnitFactor(senderSerialized)
	local receiverFactor = Shared.DeserializeUnitFactor(receiverSerialized)
	local modes = senderFactor.sharingModes
	local modeNotNone = not (#modes == 1 and modes[1] == ModeEnums.UnitFilterCategory.None)

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

---Effective sharing modes for a context (tech enrichment first, then modoption).
---@param ctx PolicyContext
---@param modOptions table
---@return string[]
function Shared.ResolveSharingModes(ctx, modOptions)
	return ctx.unitSharingModes or { modOptions.unit_sharing_mode or ModeEnums.UnitFilterCategory.None }
end

---Assemble a UnitPolicyResult from context + mod options; denials carry the
---same shape as allowed results so downstream consumers read one type.
---@param ctx PolicyContext
---@param modOptions table
---@param canShare boolean
---@return UnitPolicyResult
function Shared.BuildUnitPolicyResult(ctx, modOptions, canShare)
	local stunSeconds = tonumber(modOptions[ModeEnums.ModOptions.UnitShareStunSeconds]) or 0
	local stunCategory = modOptions[ModeEnums.ModOptions.UnitStunCategory] or ModeEnums.UnitFilterCategory.Resource
	local buildDelaySeconds = tonumber(modOptions[ModeEnums.ModOptions.ConstructorBuildDelay]) or 0
	return {
		canShare = canShare,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		sharingModes = Shared.ResolveSharingModes(ctx, modOptions),
		stunSeconds = stunSeconds,
		stunCategory = stunCategory,
		buildDelaySeconds = buildDelaySeconds,
		techBlocking = ctx.ext and ctx.ext.techBlocking or nil,
	}
end

return Shared
