--- Waves' contribution to the mission sandbox. The loader composes the
--- authoring environment from the missions manifest's requires list; each
--- contributing module ships a mission_dsl.lua returning a per-file factory.
---
--- Waves contributes the DIALS (Begin/Intensify/Surge/End and the wave
--- conditions). The PACKS a mission names — Scavengers.Skirmish — come from
--- the flavor module's own mission_dsl.lua, so the vocabulary a mission may
--- say is exactly the set of modules the missions manifest requires.

local WavesVerbs = VFS.Include("modules/waves/lib/mission_verbs.lua")

local verbs = WavesVerbs.MakeWaves()

return {
	-- No Finalize: waves arms nothing at load, so a file that fails to parse
	-- leaves no director behind.
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = { Waves = verbs } }
	end,
}
