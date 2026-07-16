local Enums = VFS.Include("modules/sharing/enums.lua")
local UnitShared = VFS.Include("modules/sharing/unit/shared.lua")
local Categories = VFS.Include("modules/sharing/unit/categories.lua")

--- The only place units change teams at runtime. Executes a transfer of
--- pre-validated units within the bounds of the pair's UnitPolicyResult
--- (policies stay pure; actions do the mutation).

---@param unitDefID integer
---@param stunCategory string?
---@param defs table
---@return boolean
local function wouldBeStunned(unitDefID, stunCategory, defs)
	if not stunCategory then
		return false
	end
	return UnitShared.IsShareableDef(unitDefID, stunCategory, defs)
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
local function validateUnits(policyResult, unitIds, springApi, unitDefs, out)
	local spring = springApi or Spring
	local defs = unitDefs or UnitDefs or (spring.GetUnitDefs and spring.GetUnitDefs()) or {}

	-- reuse caller's table when supplied; scalars reassigned and arrays cleared so stale entries never leak
	out = out or ({} --[[@as UnitValidationResult]]) -- every field is (re)assigned below
	out.status = Enums.UnitValidationOutcome.Failure
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
			local ok = UnitShared.IsShareableDef(unitDefID, modes, defs)
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
				if Categories.isMobileBuilderDef(def) then
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
		out.status = Enums.UnitValidationOutcome.Success
	elseif out.validUnitCount > 0 and out.invalidUnitCount > 0 then
		out.status = Enums.UnitValidationOutcome.PartialSuccess
	else
		out.status = Enums.UnitValidationOutcome.Failure
	end

	return out
end

---rebuild (sender,receiver) unit policy from cached factors + live gates (mirrors Synced.GetPolicy); missing factors fall back to global unit_sharing_mode
---@param senderTeamId integer
---@param receiverTeamId integer
---@param springApi EngineSynced?
---@return UnitPolicyResult
---@param ctx UnitTransferContext
---@return UnitTransferResult
local function executeUnitTransfer(ctx)
	local policyResult = ctx.policyResult

	if not policyResult.canShare then
		---@type UnitTransferResult
		return {
			success = false,
			outcome = Enums.UnitValidationOutcome.Failure,
			senderTeamId = ctx.senderTeamId,
			receiverTeamId = ctx.receiverTeamId,
			validationResult = ctx.validationResult,
			policyResult = ctx.policyResult,
		}
	end

	for _, unitId in ipairs(ctx.validationResult.validUnitIds) do
		-- ctx.given should always be false here because we short-circuit inside AllowResourceTransfer
		ctx.springRepo.TransferUnit(unitId, ctx.receiverTeamId, ctx.given)
	end

	---@type UnitTransferResult
	return {
		success = true,
		outcome = ctx.validationResult.status,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		validationResult = ctx.validationResult,
		policyResult = ctx.policyResult,
	}
end

---@type ActionDescriptor
return {
	name = "UnitTransfer",
	parameters = {
		{ name = "ctx", required = true, type = "table" },
	},
	validate = validateUnits,
	execute = executeUnitTransfer,
}
