--- The game axis's own mode vocabulary. The axis governs the Main options
--- (options_main declares mode_category = "game"), and the panel is a
--- WHITELIST: a mode shows exactly what it claims, so these verbs are how a
--- preset exposes the base rules of a match — at the lobby's own defaults,
--- unlocked, unless the preset says otherwise. Flavor modules bind their own
--- grammars to the same category (ModeEnums.ModeCategories.Game) with the
--- verbs their options need.

local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

--- What a preset file gets from including this module. The chain type lives
--- in types/mode_policy.lua — the same surface the kit reads — so the
--- language server resolves the chain the Grammar only builds at runtime.
--- Consumers annotate their include:
---
---     local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
---@class GameModeDSL
---@field Mode fun(name: string): GameModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "game" — the name only names it.

local M = {}
---@cast M GameModeDSL

--- The dozen-plus unit_restrictions_* toggles, one policy: a preset exposes
--- the family or it does not; nobody enumerates them per mode.
local RESTRICTION_KEYS = {
	"unit_restrictions_notech15",
	"unit_restrictions_notech2",
	"unit_restrictions_notech3",
	"unit_restrictions_noair",
	"unit_restrictions_nosea",
	"unit_restrictions_noextractors",
	"unit_restrictions_noconverters",
	"unit_restrictions_nofusion",
	"unit_restrictions_notacnukes",
	"unit_restrictions_nonukes",
	"unit_restrictions_noantinuke",
	"unit_restrictions_nolrpc",
	"unit_restrictions_noendgamelrpc",
}

local function option(key, value, locked)
	return { [key] = { value = value, locked = locked } }
end

local Serializers = {
	-- how the match is decided. The end rule brings its own dependent dials:
	-- territorial domination is the one deathmode with a config of its own,
	-- so choosing it exposes the round table and the elimination threshold —
	-- and no other end rule ever shows them.
	["game.end"] = function(p, lock)
		local options = option("deathmode", p.deathmode, lock.structure)
		if p.deathmode == "territorial_domination" then
			options.territorial_domination_config = { value = "25_minutes", locked = false }
			options.territorial_domination_elimination_threshold_multiplier = { value = 1.2, locked = false }
		end
		return options
	end,
	-- killed players leave their wrecks behind
	["game.wreckage"] = function(p, lock)
		return option("ffa_wreckage", p.enabled, lock.structure)
	end,
	-- start boxes are dealt at random instead of by team number
	["game.shuffle"] = function(p, lock)
		return option("teamffa_start_boxes_shuffle", p.enabled, lock.structure)
	end,
	["game.maxunits"] = function(p, lock)
		return option("maxunits", p.count, lock.dial)
	end,
	["game.draft"] = function(p, lock)
		return option("draft_mode", p.draft, lock.structure)
	end,
	["game.anonymous"] = function(p, lock)
		return option("teamcolors_anonymous_mode", p.anonymous, lock.structure)
	end,
	["game.pausedcommands"] = function(p, lock)
		return option("allowpausegameplay", p.enabled, lock.structure)
	end,
	["game.customwidgets"] = function(p, lock)
		return option("allowuserwidgets", p.enabled, lock.structure)
	end,
	["game.unitcontrolwidgets"] = function(p, lock)
		return option("allowunitcontrolwidgets", p.enabled, lock.structure)
	end,
	["game.fixedalliances"] = function(p, lock)
		return option("fixedallies", p.enabled, lock.structure)
	end,
	-- stated in the player's terms; the wire keys are the Disable* inversions
	["game.mapdeformation"] = function(p, lock)
		return option("disablemapdamage", not p.enabled, lock.structure)
	end,
	["game.fogofwar"] = function(p, lock)
		return option("disable_fogofwar", not p.enabled, lock.structure)
	end,
	["game.norush"] = function(p, lock)
		return {
			norushtimer = { value = p.minutes, locked = lock.dial },
			norushmiddlefree = { value = p.middleFree == true, locked = lock.dial },
		}
	end,
	["game.slowcomtransport"] = function(p, lock)
		return option("comm_trans_slow", p.enabled, lock.structure)
	end,
	["game.restrictions"] = function(_p, lock)
		local options = {}
		for _, key in ipairs(RESTRICTION_KEYS) do
			options[key] = { value = false, locked = lock.dial }
		end
		return options
	end,
}

---@param modeName string
---@param verb string
---@param value any
local function checkBoolean(modeName, verb, value)
	assert(type(value) == "boolean", modeName .. ": ." .. verb .. " expects true or false")
end

M.Mode = ModeBuilder.Grammar({
	category = ModeEnums.ModeCategories.Game,
	serializers = Serializers,
	verbs = {
		---How the match is decided (a deathmode item key: "com", "own_com",
		---"killall", "territorial_domination", ...). Territorial domination
		---brings its round config along. Structure-locked unless .Unlocked().
		End = function(modeName, deathmode)
			assert(type(deathmode) == "string", modeName .. ": .End expects a deathmode key")
			return { "game.end", deathmode = deathmode }
		end,

		---Eliminated players blow up but leave wreckage behind.
		Wreckage = function(modeName, enabled)
			checkBoolean(modeName, "Wreckage", enabled)
			return { "game.wreckage", enabled = enabled }
		end,

		---Start boxes are dealt at random instead of by team number.
		ShuffleStartBoxes = function(modeName, enabled)
			checkBoolean(modeName, "ShuffleStartBoxes", enabled)
			return { "game.shuffle", enabled = enabled }
		end,

		---Unit cap per player; a dial, open unless .Locked().
		MaxUnits = function(modeName, count)
			assert(type(count) == "number", modeName .. ": .MaxUnits expects a number")
			return { "game.maxunits", count = count }
		end,

		---Start-position draft order (a draft_mode item key).
		Draft = function(modeName, draft)
			assert(type(draft) == "string", modeName .. ": .Draft expects a draft_mode key")
			return { "game.draft", draft = draft }
		end,

		---Anonymous team colors (a teamcolors_anonymous_mode item key).
		Anonymous = function(modeName, anonymous)
			assert(type(anonymous) == "string", modeName .. ": .Anonymous expects a mode key")
			return { "game.anonymous", anonymous = anonymous }
		end,

		---Commands may be given while the game is paused.
		PausedCommands = function(modeName, enabled)
			checkBoolean(modeName, "PausedCommands", enabled)
			return { "game.pausedcommands", enabled = enabled }
		end,

		---Custom widgets are allowed.
		CustomWidgets = function(modeName, enabled)
			checkBoolean(modeName, "CustomWidgets", enabled)
			return { "game.customwidgets", enabled = enabled }
		end,

		---Custom unit-control widgets are allowed.
		UnitControlWidgets = function(modeName, enabled)
			checkBoolean(modeName, "UnitControlWidgets", enabled)
			return { "game.unitcontrolwidgets", enabled = enabled }
		end,

		---Alliances are fixed at start (no dynamic diplomacy).
		FixedAlliances = function(modeName, enabled)
			checkBoolean(modeName, "FixedAlliances", enabled)
			return { "game.fixedalliances", enabled = enabled }
		end,

		---The map deforms under fire. Stated in the player's terms; the wire
		---key is the inversion (disablemapdamage).
		MapDeformation = function(modeName, enabled)
			checkBoolean(modeName, "MapDeformation", enabled)
			return { "game.mapdeformation", enabled = enabled }
		end,

		---Fog of war. Stated in the player's terms; the wire key is the
		---inversion (disable_fogofwar).
		FogOfWar = function(modeName, enabled)
			checkBoolean(modeName, "FogOfWar", enabled)
			return { "game.fogofwar", enabled = enabled }
		end,

		---No attacking before the timer; minutes 0 means off.
		NoRush = function(modeName, minutes, middleFree)
			assert(type(minutes) == "number", modeName .. ": .NoRush expects minutes")
			return { "game.norush", minutes = minutes, middleFree = middleFree }
		end,

		---Commanders are slow to transport.
		SlowComTransport = function(modeName, enabled)
			checkBoolean(modeName, "SlowComTransport", enabled)
			return { "game.slowcomtransport", enabled = enabled }
		end,

		---Expose the unit-restrictions family (everything enabled by default).
		Restrictions = function(_modeName)
			return { "game.restrictions" }
		end,
	},
}) --[[@as fun(name: string): GameModeChain]]

return M
