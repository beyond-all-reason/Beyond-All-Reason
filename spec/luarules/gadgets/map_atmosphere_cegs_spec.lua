---@diagnostic disable: undefined-field

local GADGET_PATH = "luarules/gadgets/map_atmosphere_cegs.lua"

-- Loads the unsynced half for a map named like a config file, recording the engine's lighting calls.
local function loadUnsynced(world)
	local function lighting()
		return 0.5, 0.5, 0.5, 1
	end
	local function record(name)
		return function(...)
			world.calls[#world.calls + 1] = { name, ... }
		end
	end

	local env = {
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return false
			end,
			AddSyncAction = function(_, name, callback)
				world.syncActions[name] = callback
			end,
			RemoveSyncAction = function(_, name)
				world.syncActions[name] = nil
			end,
		},
		GG = world.GG,
		Game = { mapName = "TestMap" },
		VFS = {
			DirList = function()
				return { "luarules/configs/Atmosphereconfigs/testmap.lua" }
			end,
		},
		gl = { GetSun = lighting, GetAtmosphere = lighting, GetWaterRendering = lighting },
		Spring = {
			GetModOptions = function()
				return { map_atmosphere = true }
			end,
			Echo = function() end,
			SetSunLighting = record("SetSunLighting"),
			SetAtmosphere = record("SetAtmosphere"),
		},
	}
	setmetatable(env, { __index = _G })

	local chunk = assert(loadfile(GADGET_PATH))
	setfenv(chunk, env)
	chunk()
	env.gadget:Initialize()
end

describe("map_atmosphere_cegs", function()
	local world ---@type table

	local function setSun()
		world.syncActions.MapAtmosphereConfigSetSun("MapAtmosphereConfigSetSun", 0.5, 100, 0.5, 0.5, 0.5)
	end

	before_each(function()
		world = { GG = {}, calls = {}, syncActions = {} }
		loadUnsynced(world)
	end)

	it("changes the sun for the map's config", function()
		setSun()

		assert.is_true(#world.calls > 0)
	end)

	it("leaves the sun alone while GG.MapLighting is in use", function()
		world.GG.MapLightingActive = true
		setSun()

		assert.same({}, world.calls)
	end)
end)
