local LOG = LOG
local Spring = Spring --[[@as Recoil.Shared]]
local UnitDefs = UnitDefs

local Comms = require("modules/transfer/unit/comms")
local Construction = require("modules/construction/api")
local ConstructionEnums = require("modules/construction/enums")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local TransferEnums = require("modules/transfer/enums")

---@class TransferUnitValidation
---@field status string TransferEnums.UnitValidationOutcome
---@field buildDelayedUnitCount integer? Valid units that will receive the constructor build delay
---@field stunnedUnitCount integer? Valid units that will be stunned (stun category)
---@field invalidUnitCount integer
---@field invalidUnitIds integer[]
---@field invalidUnitNames string[]
---@field validUnitCount integer
---@field validUnitIds integer[]
---@field validUnitNames string[]

local Shared = Comms

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

---@param terms UnitTransferTerms
---@param unitIds integer[]
---@param springApi Recoil.Shared?
---@param unitDefs table?
---@param out table? optional pre-allocated result to fill in place (table lifting)
---@return TransferUnitValidation
function Shared.ValidateUnits(terms, unitIds, springApi, unitDefs, out)
	local spring = springApi or Spring
	local stub = spring --[[@as table]] -- a spec's stand-in may carry GetUnitDefs
	local defs = unitDefs or UnitDefs or (stub.GetUnitDefs and stub.GetUnitDefs()) or {}

	out = out or {} --[[@as TransferUnitValidation]]
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

	if (not terms.canShare) or (not unitIds or #unitIds == 0) then
		return out
	end

	local modes = terms.sharingModes or { "none" }
	local stunSeconds = tonumber(terms.stunSeconds) or 0
	local stunCategory = terms.stunCategory

	local validUnitNamesSet = {} ---@type table<string, boolean>
	local invalidUnitNamesSet = {} ---@type table<string, boolean>
	for _, unitId in ipairs(unitIds) do
		local unitDefID = spring.GetUnitDefID(unitId)
		if not unitDefID then
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

			if ok and stunSeconds > 0 and wouldBeStunned(unitDefID, stunCategory, defs) then
				local beingBuilt, buildProgress = spring.GetUnitIsBeingBuilt(unitId)
				if beingBuilt and buildProgress > 0 then
					ok = false
				end
			end

			if ok then
				out.validUnitCount = out.validUnitCount + 1
				table.insert(out.validUnitIds, unitId)
				if Construction.IsMobileBuilderDef(def) then
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

-- The policy's terms for a pair, asked by key on whichever handle asks: formed and evaluated on the frame's first
-- ask, a lookup after. Always a record; a refusal is one that says so.
---@param senderTeamId integer
---@param receiverTeamId integer
---@param springRepo Recoil.Shared the engine, or a spec's stand-in
---@return UnitTransferTerms
function Shared.Terms(senderTeamId, receiverTeamId, springRepo)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	return ModuleHandler.Ask(Transfer.UnitTransfer, springRepo, senderTeamId, receiverTeamId)
end

local function UnitTypeMatchesCategory(unitDef, category)
	local unitType = Construction.ClassifyUnitDef(unitDef)
	local categoryUnitTypes = Construction.UnitTypesFor(category)
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
