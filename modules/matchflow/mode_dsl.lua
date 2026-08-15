--- Matchflow's mode vocabulary: the verdict, as a noun a mode grammar can
--- compose. Matchflow is the one owner of the verdict, so the noun for "how
--- the match ends" and the serializer that pins deathmode live HERE — a
--- grammar that lets a mode own the end (missions does) imports both, the
--- same way a PvE flavor imports the wave dials from waves. The trigger
--- language already says MatchFlow.Victory; the mode language saying
--- MatchFlow.End is the same ownership, spoken once.

--- What a preset file gets from including this module directly:
---
---     local MatchFlow = VFS.Include("modules/matchflow/mode_dsl.lua") ---@type MatchflowModeDSL
---     ... .Own(MatchFlow.End)
---
--- Serializers ride on the same table for GRAMMARS to merge; a preset has no
--- business with them, so the class leaves them undeclared.
---@class MatchflowModeDSL
---@field End MatchflowModeNoun how the match ends; a mode that owns it scripts the verdict

local M = {}
---@cast M MatchflowModeDSL

M.End = { domain = "end" }

--- Serializers for the policies the noun can carry, keyed by policy
--- identity, ready to merge into an importing grammar's registry.
M.Serializers = {
	-- triggers own the verdict: engine elimination never ends the match
	["end.scripted"] = function(_p, lock)
		return { deathmode = { value = "neverend", locked = lock.structure } }
	end,
}

return M
