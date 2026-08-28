
local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local Packs = VFS.Include("modules/raptors/lib/packs.lua")
local Pve = VFS.Include("modules/waves/mode_dsl.lua")

--- The chain type lives in types/mode_policy.lua so the language server resolves verbs the Grammar only builds at runtime.
---@class RaptorsModeDSL
---@field Mode fun(name: string): RaptorsModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "game" — the name only names it.
---@field Raptors { Skirmish: RaptorsPackNoun, Assault: RaptorsPackNoun, Swarm: RaptorsPackNoun }

local M = {}
---@cast M RaptorsModeDSL

M.Raptors = Packs.Nouns

M.Mode = ModeBuilder.Grammar({
	category = ModeEnums.ModeCategories.Game,
	serializers = Pve.SerializersFor({
		difficulty = "raptor_difficulty",
		bossCount = "raptor_queen_count",
		bossTime = "raptor_queentimemult",
		grace = "raptor_graceperiodmult",
		waveTime = "raptor_spawntimemult",
		waveCount = "raptor_spawncountmult",
		placement = "raptor_raptorstart",
		endless = "raptor_endless",
		firstWaveBoost = "raptor_firstwavesboost",
	}),
	verbs = Pve.Verbs,
}) --[[@as fun(name: string): RaptorsModeChain]]

return M
