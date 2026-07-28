local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local TransferEnums = require("modules/transfer/enums")
local UnitShared = require("modules/transfer/unit/shared")
local state = require("modules/transfer/state")

local mayUnitScratch = {}
local mayValidationScratch = {}

return {

	---@param unitID integer
	---@param fromTeamID integer
	---@param toTeamID integer
	---@param capture boolean|nil engine-driven capture, never a policy question
	---@return boolean
	MayTransfer = function(unitID, fromTeamID, toTeamID, capture)
		if capture then
			return true
		end
		if Spring.GetGameRulesParam("isTakeInProgress") == 1 then
			return true
		end
		if Spring.GetGameRulesParam("isGiveInProgress") == 1 then
			return true
		end
		local policyResult = UnitShared.GetCachedTerms(fromTeamID, toTeamID, Spring)
		mayUnitScratch[1] = unitID
		local validation = UnitShared.ValidateUnits(policyResult, mayUnitScratch, Spring, nil, mayValidationScratch)
		return validation.status ~= TransferEnums.UnitValidationOutcome.Failure
	end,
}
