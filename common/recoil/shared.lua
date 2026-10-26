-- `local Spring = require("common/recoil/shared")`: what both Lua handles offer, the view a file that runs in either
-- holds. The checker refuses either handle's own functions in that file; so does the proxy at run time
-- (modules/module_env.lua).
local ModuleEnv = require("modules/module_env")
local Spring = ModuleEnv.Handle(nil) --[[@as Recoil.Shared]]
return Spring
