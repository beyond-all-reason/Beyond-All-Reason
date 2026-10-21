---@diagnostic disable: undefined-field

local GADGET_PATH = "luarules/gadgets/api_map_lighting.lua"

local GAME_SPEED = 30
local GL_TEXTURE_2D = 3553
local GL_TEXTURE_CUBE_MAP = 34067

local function newWorld()
	return {
		gameFrame = 0,
		sun = {
			ground = {
				ambient = { 0.5, 0.5, 0.5 },
				diffuse = { 0.8, 0.8, 0.8 },
				specular = { 0.2, 0.2, 0.2 },
				shadowDensity = 0.8,
			},
			unit = {
				ambient = { 0.4, 0.4, 0.4 },
				diffuse = { 0.7, 0.7, 0.7 },
				specular = { 0.3, 0.3, 0.3 },
				shadowDensity = 0.6,
			},
			pos = { 0, 0.6, 0.8 }, -- south, 36.87 degrees up
		},
		atmosphere = {
			skyColor = { 0.4, 0.5, 0.6 },
			sunColor = { 1, 1, 0.9 },
			cloudColor = { 0.9, 0.9, 0.9 },
			fogColor = { 0.7, 0.7, 0.8, 1 },
			fogStart = 0.5,
			fogEnd = 1.2,
			skyAxisAngle = { 0, 1, 0, 0 },
		},
		textures = {},
		calls = {},
		sent = {},
		logs = {},
		luaUI = {},
		syncActions = {},
	}
end

-- Runs the gadget file against the world table, which the stubs read from and record into.
local function loadGadget(synced, world)
	local function record(name)
		return function(...)
			world.calls[#world.calls + 1] = { name, ... }
		end
	end
	local function values(value)
		if type(value) == "table" then
			return unpack(value)
		end
		return value
	end

	local env = {
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return synced
			end,
			AddSyncAction = function(_, name, callback)
				world.syncActions[name] = callback
			end,
			RemoveSyncAction = function(_, name)
				world.syncActions[name] = nil
			end,
		},
		GG = world.GG or {},
		Game = { gameSpeed = GAME_SPEED },
		GL = { TEXTURE_CUBE_MAP = GL_TEXTURE_CUBE_MAP },
		LOG = { WARNING = "warning" },
		Script = {
			LuaUI = setmetatable({}, {
				__call = function(_, name)
					return world.luaUI[name] ~= nil
				end,
				__index = function(_, name)
					return world.luaUI[name]
				end,
			}),
		},
		SendToUnsynced = function(...)
			world.sent[#world.sent + 1] = { ... }
		end,
		VFS = {
			Include = function(path)
				if path == "mapinfo.lua" and world.mapinfo then
					return world.mapinfo
				end
				error("file not found: " .. path)
			end,
		},
		gl = {
			GetSun = function(param, mode)
				if param == "pos" then
					return values(world.sun.pos)
				end
				return values((mode == "unit" and world.sun.unit or world.sun.ground)[param])
			end,
			GetAtmosphere = function(param)
				return values(world.atmosphere[param])
			end,
			TextureInfo = function(name)
				return world.textures[name]
			end,
		},
		Spring = {
			GetGameFrame = function()
				return world.gameFrame
			end,
			Log = function(_, _, message)
				world.logs[#world.logs + 1] = message
			end,
			SetAtmosphere = record("SetAtmosphere"),
			SetSunDirection = record("SetSunDirection"),
			SetSunLighting = record("SetSunLighting"),
			SetSkyBoxTexture = record("SetSkyBoxTexture"),
		},
	}
	setmetatable(env, { __index = _G })

	local chunk = assert(loadfile(GADGET_PATH))
	setfenv(chunk, env)
	chunk()

	return env.gadget, env
end

local function assertColor(expected, actual)
	for i = 1, #expected do
		assert.near(expected[i], actual[i], 1e-6)
	end
end

describe("api_map_lighting", function()
	describe("synced", function()
		local world ---@type table
		local gadget ---@type table
		local env ---@type table
		local mapLighting ---@type table

		before_each(function()
			world = newWorld()
			world.gameFrame = 100
			gadget, env = loadGadget(true, world)
			mapLighting = env.GG.MapLighting
		end)

		it("forwards the lighting values with the frame and the duration in frames", function()
			mapLighting.SetLighting({ tint = { 1, 0.8, 0.6 }, sunElevation = 15 }, 2)
			mapLighting.SetLighting({ brightness = 0.5 })

			assert.same({
				{ "MapLighting", "SetLighting", 100, 60, { tint = { 1, 0.8, 0.6 }, sunElevation = 15 } },
				{ "MapLighting", "SetLighting", 100, 0, { brightness = 0.5 } },
			}, world.sent)
		end)

		it("forwards the hour, and the day length in frames, 0 for a stopped clock", function()
			mapLighting.SetTimeOfDay(18, 1.5, 48)
			mapLighting.SetTimeOfDay(6)

			assert.same({
				{ "MapLighting", "SetTimeOfDay", 100, 45, 18, 1440 },
				{ "MapLighting", "SetTimeOfDay", 100, 0, 6, 0 },
			}, world.sent)
		end)

		it("forwards the skybox and its rotation", function()
			mapLighting.SetSkybox("maps/sky.dds", 90)

			assert.same({ { "MapLighting", "SetSkybox", 100, "maps/sky.dds", 90 } }, world.sent)
		end)

		it("forwards a reset with its duration", function()
			mapLighting.Reset(1)
			mapLighting.Reset()

			assert.same({ { "MapLighting", "Reset", 100, 30 }, { "MapLighting", "Reset", 100, 0 } }, world.sent)
		end)

		it("removes the API on shutdown", function()
			gadget:Shutdown()

			assert.is_nil(env.GG.MapLighting)
		end)
	end)

	describe("unsynced", function()
		local world ---@type table
		local gadget ---@type table
		local env ---@type table

		local function send(command, ...)
			world.syncActions.MapLighting("MapLighting", command, ...)
		end

		local function update(frame)
			world.gameFrame = frame
			gadget:Update(1 / 60)
		end

		local function callNames()
			local names = {}
			for i, call in ipairs(world.calls) do
				names[i] = call[1]
			end
			return names
		end

		local function lastCall(name)
			for i = #world.calls, 1, -1 do
				if world.calls[i][1] == name then
					return world.calls[i]
				end
			end
		end

		local function lastLighting()
			return lastCall("SetSunLighting")[2]
		end

		before_each(function()
			world = newWorld()
			gadget, env = loadGadget(false, world)
			gadget:Initialize()
		end)

		it("leaves the map lighting alone until the first change", function()
			update(10)
			gadget:DrawGenesis()

			assert.same({}, world.calls)
			assert.same({ red = 1, green = 1, blue = 1, shadow = 1, altitude = 1 }, env.GG.NightFactor)
		end)

		it("writes the atmosphere, then the sun direction, then all sun lighting in one call", function()
			send("SetLighting", 0, 0, { brightness = 0.5 })
			update(0)

			assert.same({ "SetAtmosphere", "SetSunDirection", "SetSunLighting" }, callNames())
			local sunLighting = lastLighting()
			assertColor({ 0.25, 0.25, 0.25 }, sunLighting.groundAmbientColor)
			assertColor({ 0.4, 0.4, 0.4 }, sunLighting.groundDiffuseColor)
			assertColor({ 0.1, 0.1, 0.1 }, sunLighting.groundSpecularColor)
			assertColor({ 0.332, 0.332, 0.332 }, sunLighting.unitAmbientColor) -- units keep two thirds
			assert.near(0.8, sunLighting.groundShadowDensity, 1e-6)
			assert.near(0.6, sunLighting.modelShadowDensity, 1e-6)
			assert.is_nil(sunLighting.unitShadowDensity)

			local atmosphere = lastCall("SetAtmosphere")[2]
			assertColor({ 0.2, 0.25, 0.3 }, atmosphere.skyColor)
			assertColor({ 0.35, 0.35, 0.4, 1 }, atmosphere.fogColor)
			assertColor({ 0.5, 0.5, 0.45 }, atmosphere.sunColor)
			assert.is_nil(atmosphere.fogStart)
			assert.is_nil(atmosphere.fogEnd)

			local direction = lastCall("SetSunDirection")
			assertColor({ 0, 0.6, 0.8 }, { direction[2], direction[3], direction[4] })
		end)

		it("blends on game time and stops while the game is paused", function()
			send("SetLighting", 0, 60, { brightness = 0 })
			update(30)
			assertColor({ 0.4, 0.4, 0.4 }, lastLighting().groundDiffuseColor)

			local calls = #world.calls
			update(30)
			assert.equals(calls, #world.calls)

			update(60)
			assertColor({ 0, 0, 0 }, lastLighting().groundDiffuseColor)
		end)

		it("applies changes that arrive between two updates once", function()
			send("SetLighting", 0, 0, { brightness = 0.5 })
			send("SetLighting", 0, 0, { tint = { 1, 0, 0 } })
			send("SetTimeOfDay", 0, 0, 12, 0)
			update(0)

			assert.same({ "SetAtmosphere", "SetSunDirection", "SetSunLighting" }, callNames())
			assertColor({ 0.4, 0, 0 }, lastLighting().groundDiffuseColor)
		end)

		it("shows the map's lighting at noon", function()
			send("SetTimeOfDay", 0, 0, 12, 0)
			update(0)

			assertColor({ 0.8, 0.8, 0.8 }, lastLighting().groundDiffuseColor)
			assertColor({ 0.7, 0.7, 0.7 }, lastLighting().unitDiffuseColor)
			local direction = lastCall("SetSunDirection")
			assertColor({ 0, 0.6, 0.8 }, { direction[2], direction[3], direction[4] })
		end)

		it("dims the evening light and lowers the sun to the west", function()
			send("SetTimeOfDay", 0, 0, 18, 0)
			update(0)

			assertColor({ 0.408, 0.408, 0.408 }, lastLighting().groundDiffuseColor)
			local direction = lastCall("SetSunDirection")
			assert.is_true(direction[2] < -0.9)
			assert.is_true(direction[3] < 0.2)
		end)

		it("lights midnight dimly from opposite the sun, and drops shadows at the switch", function()
			send("SetTimeOfDay", 0, 0, 0, 0)
			update(0)
			local direction = lastCall("SetSunDirection")
			assertColor({ 0, 0.6, -0.8 }, { direction[2], direction[3], direction[4] })
			assertColor({ 0.2, 0.2, 0.2 }, lastLighting().groundDiffuseColor)

			send("SetTimeOfDay", 1, 0, 5.5, 0)
			update(1)
			assert.equals(0, lastLighting().groundShadowDensity)
		end)

		it("keeps the map's own colours at every hour, only dimmer", function()
			world.sun.ground.diffuse = { 0.8, 0.4, 0.2 }
			world.atmosphere.skyColor = { 0.6, 0.3, 0.9 }
			for step = 0, 47 do
				send("SetTimeOfDay", step, 0, step / 2, 0)
				update(step)

				local diffuse = lastLighting().groundDiffuseColor
				assert.near(0.5, diffuse[2] / diffuse[1], 1e-6)
				assert.near(0.25, diffuse[3] / diffuse[1], 1e-6)
				local sky = lastCall("SetAtmosphere")[2].skyColor
				assert.near(0.5, sky[2] / sky[1], 1e-6)
				assert.near(1.5, sky[3] / sky[1], 1e-6)
			end
		end)

		it("takes the short way round midnight", function()
			send("SetTimeOfDay", 0, 0, 22, 0)
			update(0)
			send("SetTimeOfDay", 10, 120, 2, 0)
			update(70)

			assertColor({ 0.2, 0.2, 0.2 }, lastLighting().groundDiffuseColor)
		end)

		it("keeps the clock running for a day length", function()
			send("SetTimeOfDay", 0, 0, 12, 24 * GAME_SPEED) -- an hour every 30 frames
			update(0)
			update(180)

			assertColor({ 0.408, 0.408, 0.408 }, lastLighting().groundDiffuseColor)
		end)

		it("starts a new change from the lighting shown at that moment", function()
			send("SetLighting", 0, 60, { brightness = 0 })
			update(30)
			send("SetLighting", 30, 60, { brightness = 1 })
			update(30)
			assertColor({ 0.4, 0.4, 0.4 }, lastLighting().groundDiffuseColor)

			update(60)
			assertColor({ 0.6, 0.6, 0.6 }, lastLighting().groundDiffuseColor)
			update(90)
			assertColor({ 0.8, 0.8, 0.8 }, lastLighting().groundDiffuseColor)
		end)

		it("applies the lighting values on top of the time of day", function()
			send("SetLighting", 0, 0, { brightness = 0.5 })
			send("SetTimeOfDay", 0, 0, 18, 0)
			update(0)

			assertColor({ 0.204, 0.204, 0.204 }, lastLighting().groundDiffuseColor)
		end)

		it("keeps the sun between 1 and 90 degrees above the horizon", function()
			send("SetLighting", 0, 0, { sunElevation = -10 })
			update(0)
			assert.near(math.sin(math.rad(1)), lastCall("SetSunDirection")[3], 1e-6)

			send("SetLighting", 1, 0, { sunElevation = 120 })
			update(1)
			assert.near(1, lastCall("SetSunDirection")[3], 1e-6)
		end)

		it("takes hour 24 as midnight", function()
			send("SetTimeOfDay", 0, 0, 24, 0)
			update(0)

			assertColor({ 0.2, 0.2, 0.2 }, lastLighting().groundDiffuseColor)
		end)

		it("turns the sun the short way round north", function()
			send("SetLighting", 0, 0, { sunAzimuth = 350 })
			update(0)
			send("SetLighting", 1, 60, { sunAzimuth = 10 })
			update(31)

			local direction = lastCall("SetSunDirection")
			assertColor({ 0, 0.6, -0.8 }, { direction[2], direction[3], direction[4] })
		end)

		it("stops a running clock on reset, then leaves the lighting alone", function()
			send("SetTimeOfDay", 0, 0, 12, 24 * GAME_SPEED)
			update(0)
			update(180)
			send("Reset", 180, 0)
			update(180)
			update(181)
			assert.same({ 0.8, 0.8, 0.8 }, lastLighting().groundDiffuseColor)
			assert.is_nil(env.GG.MapLightingActive)

			local calls = #world.calls
			update(400)
			assert.equals(calls, #world.calls)
		end)

		it("ignores a reset while the map's own lighting shows", function()
			send("Reset", 0, 30)
			update(0)
			update(30)

			assert.same({}, world.calls)
			assert.is_nil(env.GG.MapLightingActive)
		end)

		it("stays off when the engine has no lighting to read", function()
			world.sun.pos = {}
			send("SetLighting", 0, 0, { brightness = 0.5 })
			update(0)

			assert.same({}, world.calls)
			assert.is_nil(env.GG.MapLightingActive)
		end)

		it("tells widgets the night factor again every second, for a reloaded LuaUI", function()
			local count = 0
			world.luaUI.NightFactorChanged = function()
				count = count + 1
			end
			send("SetLighting", 0, 0, { brightness = 0.5 })
			update(0)
			gadget:Update(0.5)
			assert.equals(1, count)

			gadget:Update(0.6)
			assert.equals(2, count)
		end)

		it("restores the map lighting after a reset and reads it again on the next change", function()
			send("SetLighting", 0, 0, { brightness = 0.5 })
			update(0)
			send("Reset", 1, 0)
			update(1)
			update(2)

			local sunLighting = lastLighting()
			assert.same({ 0.8, 0.8, 0.8 }, sunLighting.groundDiffuseColor)
			assert.equals(0.6, sunLighting.modelShadowDensity)
			local direction = lastCall("SetSunDirection")
			assertColor({ 0, 0.6, 0.8 }, { direction[2], direction[3], direction[4] })
			assert.is_nil(env.GG.MapLightingActive)

			world.sun.ground.diffuse = { 1, 1, 1 }
			send("SetLighting", 3, 0, { brightness = 0.5 })
			update(3)
			assertColor({ 0.5, 0.5, 0.5 }, lastLighting().groundDiffuseColor)
			assert.is_true(env.GG.MapLightingActive)
		end)

		it("tells widgets the night factor before the sun changes", function()
			local factors = {}
			world.luaUI.NightFactorChanged = function(...)
				factors[#factors + 1] = { ... }
				factors[#factors].calls = #world.calls
			end

			send("SetLighting", 0, 0, { brightness = 0.5 })
			update(0)

			assert.equals(1, #factors)
			assertColor({ 0.5, 0.5, 0.5, 1, 1 }, factors[1])
			assert.equals(0, factors[1].calls)
			assert.near(0.5, env.GG.NightFactor.red, 1e-6)
		end)

		it("swaps the skybox during drawing, then restores fog and the lighting", function()
			world.textures["maps/sky.dds"] = { target = GL_TEXTURE_CUBE_MAP }
			send("SetSkybox", 0, "maps/sky.dds", 90)
			update(0)
			assert.is_nil(lastCall("SetSkyBoxTexture"))

			world.calls = {}
			gadget:DrawGenesis()

			assert.same(
				{ "SetSkyBoxTexture", "SetAtmosphere", "SetAtmosphere", "SetSunDirection", "SetSunLighting" },
				callNames()
			)
			assert.same({ "SetSkyBoxTexture", "maps/sky.dds" }, world.calls[1])
			assert.same({ "SetAtmosphere", { fogStart = 0.5, fogEnd = 1.2 } }, world.calls[2])
			assertColor({ 0, 1, 0, math.pi / 2 }, world.calls[3][2].skyAxisAngle)
		end)

		it("ignores a skybox texture that is not a cubemap", function()
			world.textures["maps/flat.dds"] = { target = GL_TEXTURE_2D }
			send("SetSkybox", 0, "maps/flat.dds")
			update(0)
			gadget:DrawGenesis()

			assert.is_nil(lastCall("SetSkyBoxTexture"))
			assert.equals(1, #world.logs)
		end)

		it("leaves the sky alone when the skybox texture does not load", function()
			send("SetSkybox", 0, "maps/missing.dds")
			update(0)
			gadget:DrawGenesis()

			assert.is_nil(lastCall("SetSkyBoxTexture"))
			assert.same({ "Skybox missing or not a cubemap: maps/missing.dds" }, world.logs)
		end)

		it("goes back to the map's own skybox on reset", function()
			world.mapinfo = { atmosphere = { skyBox = "sky.dds" } }
			world.textures["maps/sky.dds"] = { target = GL_TEXTURE_CUBE_MAP }
			send("SetSkybox", 0, "maps/sky.dds")
			update(0)
			gadget:DrawGenesis()

			send("Reset", 1, 0)
			update(1)
			world.calls = {}
			gadget:DrawGenesis()

			assert.same({ "SetSkyBoxTexture", "" }, world.calls[1])
		end)

		it("keeps a skybox on reset when the map has a procedural sky", function()
			world.mapinfo = { atmosphere = { skyBox = "" } }
			world.textures["maps/sky.dds"] = { target = GL_TEXTURE_CUBE_MAP }
			send("SetSkybox", 0, "maps/sky.dds")
			update(0)
			gadget:DrawGenesis()

			send("Reset", 1, 0)
			update(1)
			world.calls = {}
			gadget:DrawGenesis()

			assert.is_nil(lastCall("SetSkyBoxTexture"))
		end)

		it("writes into the GG.NightFactor that map_nightmode.lua already made", function()
			local shared = { red = 1, green = 1, blue = 1, shadow = 1, altitude = 1 }
			world.GG = { NightFactor = shared }
			gadget, env = loadGadget(false, world)
			gadget:Initialize()

			send("SetLighting", 0, 0, { brightness = 0.5 })
			update(0)

			assert.equals(shared, env.GG.NightFactor)
			assert.near(0.5, shared.red, 1e-6)
		end)

		it("restores the map lighting on shutdown", function()
			send("SetLighting", 0, 0, { brightness = 0.5 })
			update(0)
			gadget:Shutdown()

			assert.same({ 0.8, 0.8, 0.8 }, lastLighting().groundDiffuseColor)
			assert.is_nil(world.syncActions.MapLighting)
		end)
	end)
end)
