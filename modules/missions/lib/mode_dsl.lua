--- Mission mode vocabulary over modules/mode_builder.lua: nouns for what the
--- mission runtime owns, serializers for the options those policies pin.

local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

--- What a preset file gets from including this module. The chain type lives
--- in types/mode_policy.lua — the same surface the kit reads — so the
--- language server resolves verbs the Grammar only builds at runtime.
--- Consumers annotate their include:
---
---     local ModeDSL = VFS.Include("modules/missions/lib/mode_dsl.lua") ---@type MissionsModeDSL
---@class MissionsModeDSL
---@field Mode fun(name: string): MissionModeChain
---@field Match { End: MissionModeNoun, EveryUnitDef: MissionModeNoun }

local M = {}
---@cast M MissionsModeDSL

M.Match = {
	End = { domain = "end" },
	--- Every unit def in the game, loaded whether or not something else asked
	--- for it. A mission's roster and its wave packs can name any unit; the
	--- scavenger defs in particular are derived only when a scavengers AI, or
	--- ruins, or this option asks for them, and a mission is none of those.
	EveryUnitDef = { domain = "unitdefs" },
}

local Serializers = {
	-- triggers own the verdict: engine elimination never ends the match
	["end.scripted"] = function(_p, lock)
		return { deathmode = { value = "neverend", locked = lock.structure } }
	end,
	-- the mission asks for the whole unit list up front, rather than failing at
	-- the first spawn of something the game did not think it needed
	["unitdefs.all"] = function(_p, lock)
		return { forceallunits = { value = true, locked = lock.structure } }
	end,
}

M.Mode = ModeBuilder.Grammar({
	-- A mission is a way the game is played, so its preset lives on the game
	-- axis: game_mode=mission, beside standard and scavengers.
	category = ModeEnums.ModeCategories.Game,
	serializers = Serializers,
	verbs = {
		---The mission owns the noun's domain outright.
		Own = function(modeName, noun)
			return { ModeBuilder.DomainOf(modeName, "Own", noun, { ["end"] = true }, "Match.End") .. ".scripted" }
		end,

		---The mission needs the noun present from the start.
		Loads = function(modeName, noun)
			return {
				ModeBuilder.DomainOf(modeName, "Loads", noun, { unitdefs = true }, "Match.EveryUnitDef")
					.. ".all",
			}
		end,
	},
}) --[[@as fun(name: string): MissionModeChain]]

return M
