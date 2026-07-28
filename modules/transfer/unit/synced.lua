local Spring = Spring
local UnitDefs = UnitDefs

local ConstructionEnums = require("modules/construction/enums")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Shared = require("modules/transfer/unit/shared")
local TransferEnums = require("modules/transfer/enums")

local Synced = {
	ValidateUnits = Shared.ValidateUnits,
	GetModeUnitTypes = Shared.GetModeUnitTypes,
}

---@param ctx TransferContext
---@return UnitTransferTerms
function Synced.GetPolicy(ctx)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	return ModuleHandler.Evaluate(Transfer.UnitTransfer, ctx)
end

---@param springRepo Spring
---@param teamId integer
---@return boolean
local function teamActive(springRepo, teamId)
	local n = springRepo.GetTeamRulesParam(teamId, "numActivePlayers")
	if n == nil then
		return true
	end
	return tonumber(n) ~= 0
end

---@param springRepo Spring
---@param teamId integer
---@param ctx TransferContext self-context (sender==receiver==teamId) so the enricher resolves the team's modes
function Synced.CacheTeamFactor(springRepo, teamId, ctx)
	local modes = ctx.unitSharingModes
		or { springRepo.GetModOptions().unit_sharing_mode or ConstructionEnums.UnitFilterCategory.None }
	Shared.UnitFactor.Write(springRepo, teamId, { sharingModes = modes, active = teamActive(springRepo, teamId) })
end

---@class TransferUnitResult
---@field success boolean
---@field outcome string TransferEnums.UnitValidationOutcome
---@field senderTeamId integer
---@field receiverTeamId integer
---@field validationResult TransferUnitValidation
---@field policyResult UnitTransferTerms

---@param unitID integer
---@param unitDefID integer
---@param terms UnitTransferTerms
local function applyStun(unitID, unitDefID, terms)
	local stunSeconds = tonumber(terms.stunSeconds) or 0
	if stunSeconds <= 0 then
		return
	end
	local stunCategory = terms.stunCategory
	if not stunCategory or not Shared.IsShareableDef(unitDefID, stunCategory, UnitDefs) then
		return
	end
	local _, maxHealth = Spring.GetUnitHealth(unitID)
	Spring.AddUnitDamage(unitID, maxHealth * 5, stunSeconds)
end

-- Units shared under the policy: the pair's terms say whether they may pass and what happens to them, the validation
-- says which do, and those are transferred as a gift, stunned if the terms say so. What did not pass is in the result.
---@param unitIDs integer[]
---@param toTeamID integer
---@param fromTeamID integer the team being asked to give them up
---@return TransferUnitResult
function Synced.Share(unitIDs, toTeamID, fromTeamID)
	local terms = Shared.GetCachedTerms(fromTeamID, toTeamID, Spring)
	local validation = Shared.ValidateUnits(terms, unitIDs, Spring)
	for _, unitID in ipairs(validation.validUnitIds) do
		Spring.TransferUnit(unitID, toTeamID, true)
		local unitDefID = Spring.GetUnitDefID(unitID) --[[@as integer?]]
		if unitDefID then
			applyStun(unitID, unitDefID, terms)
		end
	end
	if validation.validUnitCount > 0 then
		Spring.SendLuaUIMsg("unit_transfer:success:" .. fromTeamID, "")
	end
	---@type TransferUnitResult
	return {
		success = validation.status ~= TransferEnums.UnitValidationOutcome.Failure,
		outcome = validation.status,
		senderTeamId = fromTeamID,
		receiverTeamId = toTeamID,
		validationResult = validation,
		policyResult = terms,
	}
end

-- Units handed over by fiat: no policy asked, and the engine told a give is in flight so the policy stands aside.
---@param unitIDs integer[]
---@param toTeamID integer
---@return integer transferred
function Synced.Give(unitIDs, toTeamID)
	Spring.SetGameRulesParam("isGiveInProgress", 1)
	local moved = 0
	for _, unitID in ipairs(unitIDs) do
		if Spring.TransferUnit(unitID, toTeamID, true) then
			moved = moved + 1
		end
	end
	Spring.SetGameRulesParam("isGiveInProgress", 0)
	return moved
end

return Synced
