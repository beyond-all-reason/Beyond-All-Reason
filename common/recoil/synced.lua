-- `local Spring = require("common/recoil/synced")`: the engine as the synced handle sees it. The checker refuses the
-- unsynced handle's functions in that file; so does the proxy at run time (modules/module_env.lua).
local ModuleEnv = require("modules/module_env")
local Spring = ModuleEnv.Handle("synced") --[[@as Recoil.Synced]]
return Spring
