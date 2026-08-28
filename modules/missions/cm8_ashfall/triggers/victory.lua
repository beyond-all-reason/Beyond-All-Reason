local Units = VFS.Include("modules/missions/cm8_ashfall/units.lua")
local Objectives = VFS.Include("modules/missions/cm8_ashfall/objectives.lua")

-- The mission owns the verdict: commander death means nothing until this says so.
When(Units.playerCommander.IsDestroyed()).Do(MatchFlow.Defeat(Team.Player))
When(Objectives.kill.IsComplete()).Do(MatchFlow.Victory(Team.Player))
