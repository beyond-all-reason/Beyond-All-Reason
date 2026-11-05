local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")
local summarizeSchema = require("mission_api.schema_spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes and Game.gameSpeed at load,
-- and Spring's LOS inside its GameFrame handler.
Builders.MissionApi.new():Install()

local locationRevealed = MissionSpecEnv.include(env, "luarules/mission_api/triggers/location_revealed.lua")
local onGameFrame = locationRevealed.callins.GameFrame

-- Half a second at the root spec_helper's gameSpeed of 30.
local CHECK_FRAME = 15

local SENSOR_ALLY = 0

describe("mission_api.triggers.location_revealed", function()
	-- parameter_processing fills in y at load; a spec gives it.
	local position = { x = 1000, y = 50, z = 2000 }

	local function trigger(parameters, settings)
		return Builders.Trigger.new():WithParameters(parameters):WithSettings(settings):Build()
	end

	-- The builder has no RevealedLocations yet, so each context gets its own.
	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		context.RevealedLocations = {}
		return context, context.timesFired
	end

	local losReads = {} ---@type { x: number, y: number, z: number, allyTeamID: integer }[]
	local inLos = false
	before_each(function()
		losReads, inLos = {}, false
		env.Spring.IsPosInLos = function(x, y, z, allyTeamID)
			losReads[#losReads + 1] = { x = x, y = y, z = z, allyTeamID = allyTeamID }
			return inLos
		end
	end)

	it("declares its type and requires a position and a sensorAllianceName", function()
		assert.are.same(
			{ type = "LocationRevealed", position = "Position!", sensorAllianceName = "AllianceName!" },
			summarizeSchema(locationRevealed)
		)
	end)

	it("fires when the position is in LOS, from one LOS read", function()
		local context, fired = newContext()
		inLos = true
		onGameFrame(trigger({ position = position, sensorAllianceName = SENSOR_ALLY }), "t", context, CHECK_FRAME)
		assert.are.equal(1, fired())
		assert.are.equal(1, #losReads)
	end)

	it("does not fire while the position is out of LOS", function()
		local context, fired = newContext()
		onGameFrame(trigger({ position = position, sensorAllianceName = SENSOR_ALLY }), "t", context, CHECK_FRAME)
		assert.are.equal(0, fired())
		assert.are.equal(1, #losReads)
	end)

	it("reads LOS at the position for the sensor alliance", function()
		local context = newContext()
		onGameFrame(trigger({ position = position, sensorAllianceName = 1 }), "t", context, CHECK_FRAME)
		assert.are.same({ { x = 1000, y = 50, z = 2000, allyTeamID = 1 } }, losReads)
	end)

	it("reads no LOS between checks", function()
		local context, fired = newContext()
		inLos = true
		local t = trigger({ position = position, sensorAllianceName = SENSOR_ALLY })
		for frame = 1, CHECK_FRAME - 1 do
			onGameFrame(t, "t", context, frame)
		end
		assert.are.equal(0, #losReads)
		assert.are.equal(0, fired())
	end)

	it("fires once while the position stays in LOS, and again after it leaves and returns", function()
		local context, fired = newContext()
		local t = trigger({ position = position, sensorAllianceName = SENSOR_ALLY }, { repeating = true })

		inLos = true
		onGameFrame(t, "t", context, CHECK_FRAME)
		onGameFrame(t, "t", context, 2 * CHECK_FRAME)
		assert.are.equal(1, fired())

		inLos = false
		onGameFrame(t, "t", context, 3 * CHECK_FRAME)
		inLos = true
		onGameFrame(t, "t", context, 4 * CHECK_FRAME)
		assert.are.equal(2, fired())
	end)

	it("fires once it becomes eligible while the position is already in LOS", function()
		local context, fired = newContext()
		local t = trigger({ position = position, sensorAllianceName = SENSOR_ALLY })
		inLos = true

		local activate = context.ActivateTrigger
		context.ActivateTrigger = function()
			return false
		end
		onGameFrame(t, "t", context, CHECK_FRAME)

		context.ActivateTrigger = activate
		onGameFrame(t, "t", context, 2 * CHECK_FRAME)
		assert.are.equal(1, fired())
	end)

	it("stops reading LOS once a trigger that does not repeat has fired", function()
		local context, fired = newContext()
		local t = trigger({ position = position, sensorAllianceName = SENSOR_ALLY })
		t.triggered = true
		onGameFrame(t, "t", context, CHECK_FRAME)
		assert.are.equal(0, #losReads)
		assert.are.equal(0, fired())
	end)
end)
