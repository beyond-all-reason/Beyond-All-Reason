local Objectives = VFS.Include("modules/missions/cm8_ashfall/objectives.lua")

-- Skirmish: no boss and no win condition, because the mission already has one.
local pressure = Scavengers.Skirmish

-- A minute of quiet: the director's own grace period is about spawner placement,
-- not the opening beat.
When(MatchFlow.Started()).After(60).Do(pressure.Begin().Against(Team.Player).From(0.85, 0.15).Intensity(0.3))
When(Objectives.relieve.IsComplete()).Do(pressure.Intensify(0.6))
When(Objectives.enclave.IsComplete()).Do(pressure.Surge()).Do(pressure.Intensify(1.0))
When(Objectives.kill.IsComplete()).Do(pressure.End())
