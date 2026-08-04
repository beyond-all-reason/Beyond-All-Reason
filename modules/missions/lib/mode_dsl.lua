--- Mission mode vocabulary over modules/mode_builder.lua: nouns for what the
--- mission runtime owns, serializers for the options those policies pin.
---
--- The verdict is NOT the mission runtime's: matchflow owns how the match
--- ends, so this grammar merges matchflow's serializer, and a preset
--- imports the noun from its owner DIRECTLY —
--- VFS.Include("modules/matchflow/mode_dsl.lua") — the same ownership the
--- trigger language speaks with MatchFlow.Victory. No re-export: the
--- preset names its true source.

local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local MatchflowMode = VFS.Include("modules/matchflow/mode_dsl.lua")

--- What a preset file gets from including this module. The chain type lives
--- in types/mode_policy.lua — the same surface the kit reads — so the
--- language server resolves verbs the Grammar only builds at runtime.
--- Consumers annotate their include:
---
---     local ModeDSL = VFS.Include("modules/missions/lib/mode_dsl.lua") ---@type MissionsModeDSL
---@class MissionsModeDSL
---@field Mode fun(name: string): MissionModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "game" — the name only names it.
---@field Match { EveryUnitDef: MissionModeNoun, Mission: MissionModeNoun }

local M = {}
---@cast M MissionsModeDSL

M.Match = {
	--- Every unit def in the game, loaded whether or not something else asked
	--- for it. A mission's roster and its wave packs can name any unit; the
	--- scavenger defs in particular are derived only when a scavengers AI, or
	--- ruins, or this option asks for them, and a mission is none of those.
	EveryUnitDef = { domain = "unitdefs" },
	--- The mission itself, as a choice: which directory under
	--- modules/missions/ the loader arms at game start.
	Mission = { domain = "mission" },
}

local Serializers = {
	-- the mission asks for the whole unit list up front, rather than failing at
	-- the first spawn of something the game did not think it needed
	["unitdefs.all"] = function(_p, lock)
		return { forceallunits = { value = true, locked = lock.structure } }
	end,
	-- which mission runs: exposed at its default so the lobby renders the
	-- picker; the loader arms whatever lands in it at game start
	["mission.choose"] = function(_p, lock)
		return { mission_name = { value = "none", locked = lock.structure } }
	end,
}
for name, serialize in pairs(MatchflowMode.Serializers) do
	Serializers[name] = serialize
end

M.Mode = ModeBuilder.Grammar({
	-- A mission is a way the game is played, so its preset lives on the game
	-- axis: game_mode=mission, beside standard and scavengers.
	category = ModeEnums.ModeCategories.Game,
	serializers = Serializers,
	verbs = {
		---The mission owns the noun's domain outright.
		Own = function(modeName, noun)
			return { ModeBuilder.DomainOf(modeName, "Own", noun, { ["end"] = true }, "MatchFlow.End") .. ".scripted" }
		end,

		---The mission needs the noun present from the start.
		Loads = function(modeName, noun)
			return {
				ModeBuilder.DomainOf(modeName, "Loads", noun, { unitdefs = true }, "Match.EveryUnitDef")
					.. ".all",
			}
		end,

		---The mode offers the noun as the lobby's choice.
		Choose = function(modeName, noun)
			return {
				ModeBuilder.DomainOf(modeName, "Choose", noun, { mission = true }, "Match.Mission")
					.. ".choose",
			}
		end,
	},
}) --[[@as fun(name: string): MissionModeChain]]

return M
