-- CM8 "Ashfall", Beat 6 — the verdict flows through matchflow. What the
-- objectives ARE (wording, completion, reveal cadence) lives in
-- objectives.lua; this file is only what the mission does with them. The
-- wave pressure they drive lives in waves.lua.

-- The mission owns the verdict, so commander death means nothing until this
-- says so: losing your commander is losing.
When(Unit("player_commander").IsDestroyed()).Do(MatchFlow.Defeat(Team.Player))

When(Objective("kill_the_commander").IsComplete()).Do(MatchFlow.Victory(Team.Player))
