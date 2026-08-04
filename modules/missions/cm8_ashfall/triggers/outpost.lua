local Units = VFS.Include("modules/missions/cm8_ashfall/units.lua")
local Objectives = VFS.Include("modules/missions/cm8_ashfall/objectives.lua")

-- Protection starts with the match, not the discovery: waves fight through this valley long
-- before anyone looks at it, and neutrality only stops the aiming, never the splash.
When(MatchFlow.Started()).Do(Combat.Protect(Units.hub).Until(Objectives.enclave.IsComplete()))

When(MatchFlow.Started()).When(Units.hub.IsSpotted(Team.Player)).Do(Transfer.Give(Units.outpost, Team.Player))
