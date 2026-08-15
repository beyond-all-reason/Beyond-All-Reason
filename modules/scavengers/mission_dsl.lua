--- Scavengers' contribution to the mission sandbox: the pack NOUNS.
---
--- The verbs come from waves (Begin, Intensify, Surge, End, and the wave
--- conditions); a flavor module contributes only what it is — which packs
--- exist. That split is what lets a raptors module drop into the same
--- sentence later without either side changing:
---
---     When(MatchFlow.Started())
---         .Do(Waves.Begin(Scavengers.Skirmish).Against(Team.Player))

local Packs = VFS.Include("modules/scavengers/lib/packs.lua")

return {
	-- No Finalize: naming a pack arms nothing, so a trigger file that fails
	-- to parse leaves no director behind.
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = { Scavengers = Packs.Nouns } }
	end,
}
