local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

local Comms = {}

local categoryDisplayNames = {
	[ModeEnums.UnitCategory.Combat] = "combat",
	[ModeEnums.UnitCategory.CombatT2Cons] = "combat + T2 constructor",
	[ModeEnums.UnitCategory.Production] = "production",
	[ModeEnums.UnitCategory.ProductionResource] = "production + resource",
	[ModeEnums.UnitCategory.ProductionResourceUtility] = "production + resource + utility",
	[ModeEnums.UnitCategory.ProductionUtility] = "production + utility",
	[ModeEnums.UnitCategory.Resource] = "resource",
	[ModeEnums.UnitCategory.T2Cons] = "T2 constructor",
	[ModeEnums.UnitCategory.Transport] = "transport",
	[ModeEnums.UnitCategory.Utility] = "utility",
	[ModeEnums.UnitFilterCategory.All] = "all",
}

function Comms.CategoryDisplayName(category)
	return categoryDisplayNames[category] or category
end

---@class TakeResult
---@field mode string TakeMode enum value
---@field takerName string Name of the player who issued /take
---@field sourceName string Name of the player/team being taken from
---@field transferred number Units transferred this pass
---@field stunned number Units stunned (StunDelay only)
---@field delayed number Units held back (TakeDelay first pass only)
---@field total number Total units on the source team before take
---@field category string Category enum value
---@field delaySeconds number
---@field remainingSeconds number? Seconds left for pending TakeDelay
---@field isSecondPass boolean? True when completing a TakeDelay

---@param result TakeResult
---@return string
function Comms.FormatMessage(result)
	local taker = result.takerName or "Unknown"
	local source = result.sourceName or "Unknown"

	if result.mode == ModeEnums.TakeMode.Disabled then
		return "Take is disabled"
	end

	if result.mode == ModeEnums.TakeMode.Enabled then
		return string.format(
			"%s took %d units and resources from %s",
			taker, result.transferred, source
		)
	end

	if result.mode == ModeEnums.TakeMode.StunDelay then
		if result.stunned > 0 then
			return string.format(
				"%s took %d units and resources from %s; %d %s units stunned for %ds",
				taker, result.transferred, source,
				result.stunned, Comms.CategoryDisplayName(result.category),
				result.delaySeconds
			)
		end
		return string.format(
			"%s took %d units and resources from %s",
			taker, result.transferred, source
		)
	end

	if result.mode == ModeEnums.TakeMode.TakeDelay then
		if result.isSecondPass then
			return string.format(
				"%s took remaining %d %s units and resources from %s",
				taker, result.transferred,
				Comms.CategoryDisplayName(result.category), source
			)
		end
		if result.remainingSeconds then
			return string.format(
				"%s: %ds remaining before %s's %s units can be taken",
				taker, result.remainingSeconds,
				source, Comms.CategoryDisplayName(result.category)
			)
		end
		return string.format(
			"%s took %d/%d units from %s; %d %s units available for /take in %ds",
			taker, result.transferred, result.total, source,
			result.delayed, Comms.CategoryDisplayName(result.category),
			result.delaySeconds
		)
	end

	return ""
end

return Comms
