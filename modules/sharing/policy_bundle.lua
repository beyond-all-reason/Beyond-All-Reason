local ModeEnums = VFS.Include("modules/sharing/mode_enums.lua")
local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local Opt = ModeEnums.ModOptions

-- Option keys for tier-varying policies (base, .AtT2, .AtT3).
local UNIT_KEY = { [0] = Opt.UnitSharingMode, [2] = Opt.UnitSharingModeAtT2, [3] = Opt.UnitSharingModeAtT3 }
local TAX_KEY = { [0] = Opt.TaxResourceSharingAmount, [2] = Opt.TaxResourceSharingAmountAtT2, [3] = Opt.TaxResourceSharingAmountAtT3 }

-- A mode is a named bundle of policies; modOptions is the serialization the
-- lobby/SPADS transport understands. Each policy serializes only the options it
-- owns: structural choices take the structure lock, numeric dials the dial lock.
local Serializers = {
	["unit.allow"] = function(p, lock)
		return { [UNIT_KEY[p.tier or 0]] = { value = p.category or ModeEnums.UnitFilterCategory.All, locked = lock.structure } }
	end,
	["unit.deny"] = function(p, lock)
		return { [UNIT_KEY[p.tier or 0]] = { value = ModeEnums.UnitFilterCategory.None, locked = lock.structure } }
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
		return { [TAX_KEY[p.tier or 0]] = { value = p.rate, locked = lock.dial, ui = p.ui } }
	end,
	["assist.allow"] = function(_p, lock)
		return { [Opt.AlliedAssistMode] = { value = ModeEnums.AlliedAssistMode.Enabled, locked = lock.structure } }
	end,
	["assist.deny"] = function(_p, lock)
		return { [Opt.AlliedAssistMode] = { value = ModeEnums.AlliedAssistMode.Disabled, locked = lock.structure } }
	end,
	["reclaim.allow"] = function(_p, lock)
		return { [Opt.AlliedUnitReclaimMode] = { value = ModeEnums.AlliedUnitReclaimMode.Enabled, locked = lock.structure } }
	end,
	["reclaim.deny"] = function(_p, lock)
		return { [Opt.AlliedUnitReclaimMode] = { value = ModeEnums.AlliedUnitReclaimMode.Disabled, locked = lock.structure } }
	end,
	["resurrect.allow"] = function(_p, lock)
		return { [Opt.AllowPartialResurrection] = { value = ModeEnums.AllowPartialResurrection.Enabled, locked = lock.structure } }
	end,
	["resurrect.deny"] = function(_p, lock)
		return { [Opt.AllowPartialResurrection] = { value = ModeEnums.AllowPartialResurrection.Disabled, locked = lock.structure } }
	end,
	["take.allow"] = function(_p, lock)
		return { [Opt.TakeMode] = { value = ModeEnums.TakeMode.Enabled, locked = lock.structure } }
	end,
	["take.deny"] = function(_p, lock)
		return { [Opt.TakeMode] = { value = ModeEnums.TakeMode.Disabled, locked = lock.structure } }
	end,
	["take.stun"] = function(_p, lock)
		return { [Opt.TakeMode] = { value = ModeEnums.TakeMode.StunDelay, locked = lock.structure } }
	end,
	["take.defer"] = function(_p, lock)
		return { [Opt.TakeMode] = { value = ModeEnums.TakeMode.TakeDelay, locked = lock.structure } }
	end,
	["take.delay"] = function(p, lock)
		return {
			[Opt.TakeDelaySeconds] = { value = p.seconds, locked = lock.dial },
			[Opt.TakeDelayCategory] = { value = p.category, locked = lock.structure },
		}
	end,
	["build.delay"] = function(p, lock)
		return { [Opt.ConstructorBuildDelay] = { value = p.seconds, locked = lock.dial } }
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

---Serialize a policy bundle to the modOptions table a ModeConfig declares.
---@param bundle ModePolicyRef[]
---@return table<string, ModOptionConfig>
function M.toModOptions(bundle)
	return ModeBuilder.ToModOptions(Serializers, bundle)
end

return M
