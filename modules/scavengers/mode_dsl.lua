--- Scavengers' mode vocabulary: the generic PvE grammar bound to the scav_*
--- wire keys.
---
--- Every key below already exists and already means what it means to a lobby
--- and to a SPADS config. The preset does not invent a mode option; it
--- SERIALIZES the ones there are, which is why turning the mode on in an
--- existing lobby changes nothing about how the game is set up.
---
---     Mode("Scavengers")
---         .Difficulty(Scavengers.Horde, "normal").Unlocked()
---         .Boss(Scavengers.Horde, 1)

local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local Packs = VFS.Include("modules/scavengers/lib/packs.lua")
local Pve = VFS.Include("modules/waves/mode_dsl.lua")

--- What a preset file gets from including this module. The chain type lives
--- in types/mode_policy.lua — the same surface the kit reads — so the
--- language server resolves verbs the Grammar only builds at runtime.
--- Consumers annotate their include:
---
---     local ModeDSL = VFS.Include("modules/scavengers/mode_dsl.lua") ---@type ScavengersModeDSL
---@class ScavengersModeDSL
---@field Mode fun(name: string): ScavengersModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "game" — the name only names it.
---@field Scavengers { Skirmish: ScavengersPackNoun, Assault: ScavengersPackNoun, Horde: ScavengersPackNoun }

local M = {}
---@cast M ScavengersModeDSL

-- The nouns ARE the packs: a mode dials the same Horde a mission could name.
M.Scavengers = Packs.Nouns

M.Mode = ModeBuilder.Grammar({
	-- Scavengers is a way the game is played, so its preset lives on the game
	-- axis; the scav_defense_options section hands the axis its defaults by
	-- declaring mode_category = "game".
	category = ModeEnums.ModeCategories.Game,
	serializers = Pve.SerializersFor({
		difficulty = "scav_difficulty",
		bossCount = "scav_boss_count",
		bossTime = "scav_bosstimemult",
		grace = "scav_graceperiodmult",
		waveTime = "scav_spawntimemult",
		waveCount = "scav_spawncountmult",
		placement = "scav_scavstart",
		endless = "scav_endless",
	}),
	verbs = Pve.Verbs,
}) --[[@as fun(name: string): ScavengersModeChain]]

return M
