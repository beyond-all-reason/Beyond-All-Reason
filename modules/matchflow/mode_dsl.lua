
---@class MatchflowModeDSL
---@field End MatchflowModeNoun how the match ends; a mode that owns it scripts the verdict

local M = {}
---@cast M MatchflowModeDSL

M.End = { domain = "end" }

M.Serializers = {
	-- triggers own the verdict: engine elimination never ends the match
	["end.scripted"] = function(_p, lock)
		return { deathmode = { value = "neverend", locked = lock.structure } }
	end,
}

return M
