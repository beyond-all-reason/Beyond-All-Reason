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
local Packs = VFS.Include("modules/scavengers/lib/packs.lua")
local Pve = VFS.Include("modules/waves/mode_dsl.lua")

local M = {}

-- The nouns ARE the packs: a mode dials the same Horde a mission could name.
M.Scavengers = Packs.Nouns

M.Mode = ModeBuilder.Grammar({
	-- The category is the modoption section, which is how the export pairs a
	-- preset with the defaults it overrides.
	category = "scav_defense_options",
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
	chainVerbs = {
		---A mode that needs a bot on the field.
		---
		---This is the one thing the modoptions cannot say. Scavengers are
		---activated by the presence of a scavengers AI, not by a modoption —
		---which is what keeps every existing lobby working — so the preset
		---has to tell the lobby to field one. It goes into the exported JSON
		---beside the options, and nothing in the game reads it.
		---@param chain table
		---@param _modeName string
		---@param aiName string
		Bot = function(chain, _modeName, aiName)
			assert(type(aiName) == "string", "Mode(...).Bot expects an AI short name")
			chain.bots = chain.bots or {}
			chain.bots[#chain.bots + 1] = aiName
		end,
	},
})

return M
