
local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local Packs = VFS.Include("modules/scavengers/lib/packs.lua")
local Pve = VFS.Include("modules/waves/mode_dsl.lua")

---@class ScavengersModeDSL
---@field Mode fun(name: string): ScavengersModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "game" — the name only names it.
---@field Scavengers { Skirmish: ScavengersPackNoun, Assault: ScavengersPackNoun, Horde: ScavengersPackNoun }

local M = {}
---@cast M ScavengersModeDSL

M.Scavengers = Packs.Nouns

M.Mode = ModeBuilder.Grammar({
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
