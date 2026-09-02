local BAR = BAR

local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local TechBlockingComms = require("modules/tech/blocking_comms")
local TechTier = require("modules/tech/tier")

---@type TransferContract
local Transfer = Policies.Contract(Modules.Transfer)
local teamTerms = Transfer.TeamTerms
local teamPairing = Transfer.TeamPairing
local unitTermsNotes = Transfer.UnitTermsNotes
local resourceTermsNotes = Transfer.ResourceTermsNotes

-- What tech tells transfer about a team: the tax rate and sharing modes its level unlocks, and, as notes on the
-- terms a player reads, what the next level would open
--

---@param teamID integer
---@param modOptions table
---@param springRepo Spring
---@return TechCoreLadder|nil nil when tech keeps no level for the team
local function ladderOf(teamID, modOptions, springRepo)
	local tb = TechBlockingComms.fromTeamRules(teamID, springRepo)
	if tb == nil then
		return nil
	end
	---@type TechContract
	local Tech = ModuleHandler.Contract(Modules.Tech)
	---@type TechTierRequest
	local request = {
		modOptions = modOptions,
		level = tb.level,
		points = tb.points,
		t2Threshold = tb.t2Threshold,
		t3Threshold = tb.t3Threshold,
	}
	return ModuleHandler.Evaluate(Tech.TechCore, request)
end

Policies.For(teamTerms).Provide(teamTerms.TaxRate, function(ctx)
	local level = tonumber(ctx.springRepo.GetTeamRulesParam(ctx.teamId, "tech_level") or 1) or 1
	local rate = tonumber(TechTier.resolveByTechLevel(ctx.modOptions, "tax_resource_sharing_amount", level))
	return (rate ~= nil and rate >= 0) and rate or nil
end)

Policies.For(teamPairing).Provide(teamPairing.UnitSharingModes, teamPairing.TaxRate, function(ctx)
	local tb = TechBlockingComms.fromTeamRules(ctx.senderTeamId, ctx.springRepo)
	---@type TechContract
	local Tech = ModuleHandler.Contract(Modules.Tech)
	---@type TechTierRequest
	local request = {
		modOptions = ctx.modOptions,
		level = tb and tb.level or 1,
		points = tb and tb.points or 0,
		t2Threshold = tb and tb.t2Threshold or 0,
		t3Threshold = tb and tb.t3Threshold or 0,
	}
	local tier = ModuleHandler.Evaluate(Tech.TechCore, request)
	local taxRate = (tier.taxRate ~= nil and tier.taxRate >= 0) and tier.taxRate or nil
	return tier.modes, taxRate
end)

Policies.For(unitTermsNotes).Provide(unitTermsNotes.Opening, function(ctx)
	local ladder = ladderOf(ctx.terms.senderTeamId, ctx.modOptions, ctx.springRepo)
	local unlock = ladder and ladder.blocking.unitTransfer
	if unlock == nil then
		return nil
	end
	return BAR.I18N("ui.techBlocking.opening.units", {
		unitSharingMode = BAR.I18N("ui.unitSharingMode." .. tostring(unlock.unlockValue)),
		level = unlock.unlockLevel,
		points = ladder.blocking.points,
		threshold = unlock.unlockThreshold,
	})
end)

Policies.For(resourceTermsNotes).Provide(resourceTermsNotes.Opening, function(ctx)
	local ladder = ladderOf(ctx.terms.senderTeamId, ctx.modOptions, ctx.springRepo)
	local unlock = ladder and ladder.blocking.metalTransfer
	if unlock == nil then
		return nil
	end
	return BAR.I18N("ui.techBlocking.opening.tax", {
		rate = math.floor((tonumber(unlock.unlockValue) or 0) * 100 + 0.5),
		level = unlock.unlockLevel,
		points = ladder.blocking.points,
		threshold = unlock.unlockThreshold,
	})
end)
