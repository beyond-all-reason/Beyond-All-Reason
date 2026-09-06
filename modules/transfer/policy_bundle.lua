local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local Opt = TransferEnums.ModOptions
local ConstructionOpt = ConstructionEnums.ModOptions

local UNIT_KEY = { [0] = Opt.UnitSharingMode, [2] = Opt.UnitSharingModeAtT2, [3] = Opt.UnitSharingModeAtT3 }
local TAX_KEY = {
	[0] = Opt.TaxResourceSharingAmount,
	[2] = Opt.TaxResourceSharingAmountAtT2,
	[3] = Opt.TaxResourceSharingAmountAtT3,
}

local Serializers = {
	["unit.allow"] = function(p, lock)
		return {
			[UNIT_KEY[p.tier or 0]] = {
				value = p.category or ConstructionEnums.UnitFilterCategory.All,
				locked = lock.structure,
			},
		}
	end,
	["unit.deny"] = function(p, lock)
		return {
			[UNIT_KEY[p.tier or 0]] = { value = ConstructionEnums.UnitFilterCategory.None, locked = lock.structure },
		}
	end,
	["unit.stun"] = function(p, lock)
		return {
			[Opt.UnitShareStunSeconds] = { value = p.seconds, locked = lock.dial },
			[Opt.UnitStunCategory] = { value = p.category, locked = lock.structure },
		}
	end,
	["resource.allow"] = function(_p, lock)
		return { [Opt.ResourceSharingEnabled] = { value = true, locked = lock.structure } }
	end,
	["resource.deny"] = function(_p, lock)
		return { [Opt.ResourceSharingEnabled] = { value = false, locked = lock.structure } }
	end,
	["resource.tax"] = function(p, lock)
		assert(
			p.category == nil,
			".Tax(Transfer.Resources."
				.. tostring(p.category)
				.. ", ...) cannot be serialized yet:"
				.. " the tax modoptions are per tier, not per resource. Tax Transfer.Resources for now."
		)
		return { [TAX_KEY[p.tier or 0]] = { value = p.rate, locked = lock.dial, ui = p.ui } }
	end,
	["assist.allow"] = function(_p, lock)
		return {
			[ConstructionOpt.AlliedAssistMode] = {
				value = ConstructionEnums.AlliedAssistMode.Enabled,
				locked = lock.structure,
			},
		}
	end,
	["assist.deny"] = function(_p, lock)
		return {
			[ConstructionOpt.AlliedAssistMode] = {
				value = ConstructionEnums.AlliedAssistMode.Disabled,
				locked = lock.structure,
			},
		}
	end,
	["reclaim.allow"] = function(_p, lock)
		return {
			[ConstructionOpt.AlliedUnitReclaimMode] = {
				value = ConstructionEnums.AlliedUnitReclaimMode.Enabled,
				locked = lock.structure,
			},
		}
	end,
	["reclaim.deny"] = function(_p, lock)
		return {
			[ConstructionOpt.AlliedUnitReclaimMode] = {
				value = ConstructionEnums.AlliedUnitReclaimMode.Disabled,
				locked = lock.structure,
			},
		}
	end,
	["resurrect.allow"] = function(_p, lock)
		return {
			[ConstructionOpt.AllowPartialResurrection] = {
				value = ConstructionEnums.AllowPartialResurrection.Enabled,
				locked = lock.structure,
			},
		}
	end,
	["resurrect.deny"] = function(_p, lock)
		return {
			[ConstructionOpt.AllowPartialResurrection] = {
				value = ConstructionEnums.AllowPartialResurrection.Disabled,
				locked = lock.structure,
			},
		}
	end,
	["take.allow"] = function(_p, lock)
		return { [Opt.TakeMode] = { value = TransferEnums.TakeMode.Enabled, locked = lock.structure } }
	end,
	["take.deny"] = function(_p, lock)
		return { [Opt.TakeMode] = { value = TransferEnums.TakeMode.Disabled, locked = lock.structure } }
	end,
	["take.stun"] = function(_p, lock)
		return { [Opt.TakeMode] = { value = TransferEnums.TakeMode.StunDelay, locked = lock.structure } }
	end,
	["take.defer"] = function(_p, lock)
		return { [Opt.TakeMode] = { value = TransferEnums.TakeMode.TakeDelay, locked = lock.structure } }
	end,
	["take.delay"] = function(p, lock)
		return {
			[Opt.TakeDelaySeconds] = { value = p.seconds, locked = lock.dial },
			[Opt.TakeDelayCategory] = { value = p.category, locked = lock.structure },
		}
	end,
	["build.delay"] = function(p, lock)
		return { [ConstructionOpt.ConstructorBuildDelay] = { value = p.seconds, locked = lock.dial } }
	end,
	["tech.gate"] = function(p, lock)
		return {
			[Opt.TechBlocking] = { value = true, locked = lock.structure },
			[Opt.T2TechThreshold] = { value = p.t2, locked = lock.dial },
			[Opt.T3TechThreshold] = { value = p.t3, locked = lock.dial },
		}
	end,
	["tech.open"] = function(p, lock)
		return {
			[Opt.TechBlocking] = { value = false, locked = lock.structure },
			[Opt.T2TechThreshold] = { value = p.t2, locked = lock.dial },
			[Opt.T3TechThreshold] = { value = p.t3, locked = lock.dial },
		}
	end,
}

local M = {}

M.Serializers = Serializers

---@param bundle ModePolicyRef[]
---@return table<string, ModOptionConfig>
function M.toModOptions(bundle)
	return ModeBuilder.ToModOptions(Serializers, bundle)
end

return M
