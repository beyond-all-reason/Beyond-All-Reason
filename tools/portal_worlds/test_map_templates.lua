-- SPDX-License-Identifier: GPL-2.0-or-later
-- Run from the game root with lua5.1 tools/portal_worlds/test_map_templates.lua.
local function Load(path, env)
	setmetatable(env, { __index = _G })
	env._G = env
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	chunk()
end
local messages = {}
local env = {
	gadget = {},
	gadgetHandler = {
		IsSyncedCode = function()
			return true
		end,
	},
	Spring = {
		GetGaiaTeamID = function()
			return 0
		end,
		Echo = function(message, name)
			messages[#messages + 1] = { message, name }
		end,
	},
	VFS = {
		FileExists = function()
			return true
		end,
		Include = function()
			return { unitlist = { { name = "invalid_fixture_unit" } } }
		end,
	},
	UnitDefNames = {},
}
Load("tools/portal_worlds/map-template/LuaGaia/Gadgets/FP_featureplacer.lua", env)
rawget(env.gadget, "GamePreload")(env.gadget)
assert(messages[#messages][2] == "invalid_fixture_unit", "Invalid unit diagnostic lost its name")
assert(rawget(env, "featurecfg") == nil, "Feature configuration leaked into the map environment")
for _, present in ipairs({ false, true }) do
	local called = 0
	local environment = {
		VFS = {
			Include = function(path)
				assert(path == "LuaGadgets/gadgets.lua")
			end,
		},
	}
	if present then
		environment.AllowUnsafeChanges = function()
			called = called + 1
		end
	end
	Load("tools/portal_worlds/map-template/LuaGaia/main.lua", environment)
	assert(called == (present and 1 or 0), "Optional LuaGaia entry point was not preserved")
end
print("Portal map template checks passed")
