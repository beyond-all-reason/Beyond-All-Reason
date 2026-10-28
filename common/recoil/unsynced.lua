-- `local Spring = require("common/recoil/unsynced")`: the engine as the unsynced handle sees it. The checker refuses
-- the synced handle's functions in that file; so does the proxy at run time (modules/module_env.lua).
local ModuleEnv = require("modules/module_env")
local Spring = ModuleEnv.Handle("unsynced") --[[@as Recoil.Unsynced]]
return Spring
