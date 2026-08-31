
local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local MatchflowMode = VFS.Include("modules/matchflow/mode_dsl.lua")

--- The chain type lives in types/mode_policy.lua so the language server resolves
--- verbs the Grammar only builds at runtime.
---@class MissionsModeDSL
---@field Mode fun(name: string): MissionModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "game" — the name only names it.
---@field Match { EveryUnitDef: MissionModeNoun, Mission: MissionModeNoun }

local M = {}
---@cast M MissionsModeDSL

M.Match = {
	--- Scavenger defs are derived only when a scavengers AI, ruins, or this option
	--- asks for them, and a mission is none of the first two.
	EveryUnitDef = { domain = "unitdefs" },
	Mission = { domain = "mission" },
}

local Serializers = {
	["unitdefs.all"] = function(_p, lock)
		return { forceallunits = { value = true, locked = lock.structure } }
	end,
	-- exposed at its default so the lobby renders the picker
	["mission.choose"] = function(_p, lock)
		return { mission_name = { value = "none", locked = lock.structure } }
	end,
}
for name, serialize in pairs(MatchflowMode.Serializers) do
	Serializers[name] = serialize
end

M.Mode = ModeBuilder.Grammar({
	category = ModeEnums.ModeCategories.Game,
	serializers = Serializers,
	verbs = {
		Own = function(modeName, noun)
			return { ModeBuilder.DomainOf(modeName, "Own", noun, { ["end"] = true }, "MatchFlow.End") .. ".scripted" }
		end,

		Loads = function(modeName, noun)
			return {
				ModeBuilder.DomainOf(modeName, "Loads", noun, { unitdefs = true }, "Match.EveryUnitDef") .. ".all",
			}
		end,

		Choose = function(modeName, noun)
			return {
				ModeBuilder.DomainOf(modeName, "Choose", noun, { mission = true }, "Match.Mission") .. ".choose",
			}
		end,
	},
}) --[[@as fun(name: string): MissionModeChain]]

return M
