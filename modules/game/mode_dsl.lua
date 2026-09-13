local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/game/enums.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

---@class GameModeDSL
---@field DeathMode DeathModeFields the keys .End accepts
---@field DraftMode DraftModeFields the keys .Draft accepts
---@field AnonymousMode AnonymousModeFields the keys .Anonymous accepts
---@field Mode fun(name: string): GameModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "game" — the name only names it.

local M = {}
---@cast M GameModeDSL
M.DeathMode = ModeEnums.DeathMode
M.DraftMode = ModeEnums.DraftMode
M.AnonymousMode = ModeEnums.AnonymousMode

local OneOf = ModeBuilder.OneOf
local Verb = ModeBuilder.Verb

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

---@param key string
---@param value string|number|boolean
---@param locked boolean
---@return table<string, ModOptionConfig>
local function option(key, value, locked)
	return { [key] = { value = value, locked = locked } }
end

---@param modeName string
---@param verb string
---@param value any
local function checkBoolean(modeName, verb, value)
	assert(type(value) == "boolean", modeName .. ": ." .. verb .. " expects true or false")
end

---@param verbName string
---@param key string the modoption
---@param invert boolean|nil the wire key is the Disable* inversion of what the preset says
---@return ModeVerb
local function flag(verbName, key, invert)
	return Verb(function(modeName, enabled)
		checkBoolean(modeName, verbName, enabled)
		return { enabled = enabled }
	end, function(p, lock)
		return option(key, invert and not p.enabled or p.enabled, lock.noun)
	end)
end

local verbs = {
	End = Verb(function(modeName, deathmode)
		OneOf(modeName, "Death", ModeEnums.DeathMode, deathmode)
		return { deathmode = deathmode }
	end, function(p, lock)
		local options = option("deathmode", p.deathmode, lock.noun)
		if p.deathmode == ModeEnums.DeathMode.TerritorialDomination then
			options.territorial_domination_config = { value = "25_minutes", locked = false }
			options.territorial_domination_elimination_threshold_multiplier = { value = 1.2, locked = false }
		end
		return options
	end),

	Wreckage = flag("Wreckage", "ffa_wreckage"),
	ShuffleStartBoxes = flag("ShuffleStartBoxes", "teamffa_start_boxes_shuffle"),

	MaxUnits = Verb(function(modeName, count)
		assert(type(count) == "number", modeName .. ": .MaxUnits expects a number")
		return { count = count }
	end, function(p, lock)
		return option("maxunits", p.count, lock.dial)
	end),

	Draft = Verb(function(modeName, draft)
		OneOf(modeName, "Draft", ModeEnums.DraftMode, draft)
		return { draft = draft }
	end, function(p, lock)
		return option("draft_mode", p.draft, lock.noun)
	end),

	Anonymous = Verb(function(modeName, anonymous)
		OneOf(modeName, "Anonymous", ModeEnums.AnonymousMode, anonymous)
		return { anonymous = anonymous }
	end, function(p, lock)
		return option("teamcolors_anonymous_mode", p.anonymous, lock.noun)
	end),

	PausedCommands = flag("PausedCommands", "allowpausegameplay"),
	CustomWidgets = flag("CustomWidgets", "allowuserwidgets"),
	UnitControlWidgets = flag("UnitControlWidgets", "allowunitcontrolwidgets"),
	FixedAlliances = flag("FixedAlliances", "fixedallies"),
	MapDeformation = flag("MapDeformation", "disablemapdamage", true),
	FogOfWar = flag("FogOfWar", "disable_fogofwar", true),

	NoRush = Verb(function(modeName, minutes, middleFree)
		assert(type(minutes) == "number", modeName .. ": .NoRush expects minutes")
		return { minutes = minutes, middleFree = middleFree }
	end, function(p, lock)
		return {
			norushtimer = { value = p.minutes, locked = lock.dial },
			norushmiddlefree = { value = p.middleFree == true, locked = lock.dial },
		}
	end),

	UnitRestrictions = Verb(function()
		return {}
	end, function(_p, lock)
		local options = {}
		for _, key in ipairs(RESTRICTION_KEYS) do
			options[key] = { value = false, locked = lock.dial }
		end
		return options
	end),
}

M.Mode = ModeBuilder.Grammar({
	category = ModeEnums.ModeCategories.Game,
	verbs = ModeBuilder.Verbs(verbs, ModuleHandler.ModeVerbs(ModeEnums.ModeCategories.Game)),
}) --[[@as fun(name: string): GameModeChain]]

return M
