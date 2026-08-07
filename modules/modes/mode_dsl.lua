--- The game axis's own mode vocabulary. The axis governs the Main options
--- (options_main declares mode_category = "game"), so its verbs speak about
--- the base rules of a match — how it ends, what the fallen leave behind.
--- Standard pins none of them: it IS the absence of a flavor, and the
--- governed dials stay open. Flavor modules bind their own grammars to the
--- same category (ModeEnums.ModeCategories.Game) with the verbs their
--- options need.

local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

--- What a preset file gets from including this module. The chain type lives
--- in types/mode_policy.lua — the same surface the kit reads — so the
--- language server resolves the chain the Grammar only builds at runtime.
--- Consumers annotate their include:
---
---     local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
---@class GameModeDSL
---@field Mode fun(name: string): GameModeChain

local M = {}
---@cast M GameModeDSL

local Serializers = {
	-- how the match is decided: the deathmode wire key
	["game.end"] = function(p, lock)
		return { deathmode = { value = p.deathmode, locked = lock.structure } }
	end,
	-- killed players leave their wrecks behind
	["game.wreckage"] = function(p, lock)
		return { ffa_wreckage = { value = p.enabled, locked = lock.structure } }
	end,
	-- start boxes are dealt at random instead of by team number
	["game.shuffle"] = function(p, lock)
		return { teamffa_start_boxes_shuffle = { value = p.enabled, locked = lock.structure } }
	end,
}

M.Mode = ModeBuilder.Grammar({
	category = ModeEnums.ModeCategories.Game,
	serializers = Serializers,
	verbs = {
		---How the match is decided (a deathmode item key: "com", "own_com",
		---"killall", ...). Structure-locked unless the preset says .Unlocked().
		End = function(modeName, deathmode)
			assert(type(deathmode) == "string", modeName .. ": .End expects a deathmode key")
			return { "game.end", deathmode = deathmode }
		end,

		---Eliminated players blow up but leave wreckage behind.
		Wreckage = function(modeName, enabled)
			assert(type(enabled) == "boolean", modeName .. ": .Wreckage expects true or false")
			return { "game.wreckage", enabled = enabled }
		end,

		---Start boxes are dealt at random instead of by team number.
		ShuffleStartBoxes = function(modeName, enabled)
			assert(type(enabled) == "boolean", modeName .. ": .ShuffleStartBoxes expects true or false")
			return { "game.shuffle", enabled = enabled }
		end,
	},
}) --[[@as fun(name: string): GameModeChain]]

return M
