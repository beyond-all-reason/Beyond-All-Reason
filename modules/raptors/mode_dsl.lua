--- Raptors' mode vocabulary: the generic PvE grammar bound to the raptor_*
--- wire keys.
---
--- Every key below already exists and already means what it means to a lobby
--- and to a SPADS config. The preset does not invent a mode option; it
--- SERIALIZES the ones there are. The queen is the flavor's boss, which is
--- the whole translation.
---
---     Mode("Raptors")
---         .Difficulty(Raptors.Swarm, "normal").Unlocked()
---         .Boss(Raptors.Swarm, 1)

local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local Pve = VFS.Include("modules/waves/mode_dsl.lua")

--- What a preset file gets from including this module. The chain type lives
--- in types/mode_policy.lua — the same surface the kit reads — so the
--- language server resolves verbs the Grammar only builds at runtime.
--- Consumers annotate their include:
---
---     local ModeDSL = VFS.Include("modules/raptors/mode_dsl.lua") ---@type RaptorsModeDSL
---@class RaptorsModeDSL
---@field Mode fun(name: string): RaptorsModeChain Start a preset. The category is not a parameter: the grammar binds every chain from this module to "game" — the name only names it.
---@field Raptors { Swarm: RaptorsPackNoun }

local M = {}
---@cast M RaptorsModeDSL

-- The one noun, declared ahead of its pack: when raptors migrates onto the
-- wave director, "raptors.swarm" is the pack this dial has been naming all
-- along. Until then the old spawner reads the same options the serializers
-- write, and the noun is only an address.
M.Raptors = {
	Swarm = { domain = "waves", name = "raptors.swarm" },
}

M.Mode = ModeBuilder.Grammar({
	-- Raptors is a way the game is played, so its preset lives on the game
	-- axis; the raptor_defense_options section hands the axis its defaults by
	-- declaring mode_category = "game".
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
