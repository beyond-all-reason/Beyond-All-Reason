--- The scavengers roster, as the engine still asks for it.
---
--- The 2,971 lines that used to live here are now modules/scavengers/data/
--- (inert tables) and modules/scavengers/lib/defs_build.lua (the program).
--- This file stays because LuaRules/Configs is where the spawner looks, and
--- moving the roster is not the same change as moving the spawner.
---
--- FromEngine is the one adapter that reads Spring; Build takes everything
--- injected, which is why the roster can now be built in a spec, in a lobby,
--- or twice in one game with different settings.

return VFS.Include("modules/scavengers/lib/defs_build.lua").FromEngine()
