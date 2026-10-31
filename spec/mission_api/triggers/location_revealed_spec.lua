local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")
local summarizeSchema = require("mission_api.schema_spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes and Game.gameSpeed at load,
-- and Spring's ground height and LOS inside its GameFrame handler.
Builders.MissionApi.new():Install()

local locationRevealed = MissionSpecEnv.include(env, "luarules/mission_api/triggers/location_revealed.lua")
local onGameFrame = locationRevealed.callins.GameFrame

-- Half a second at the root spec_helper's gameSpeed of 30.
local CHECK_FRAME = 15

local SENSOR_ALLY = 0

describe("mission_api.triggers.location_revealed", function()
	local function trigger(parameters, settings)
		return Builders.Trigger.new():WithParameters(parameters):WithSettings(settings):Build()
	end

	-- The builder has no RevealedLocations yet, so each context gets its own.
	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		context.RevealedLocations = {}
		return context, context.timesFired
	end

	-- Points in LOS are listed as "x:z" keys; every LOS read is recorded.
	local losReads = {} ---@type { x: number, y: number, z: number, allyTeamID: integer }[]
	local function setVisiblePoints(visible)
		env.Spring.IsPosInLos = function(x, y, z, allyTeamID)
			losReads[#losReads + 1] = { x = x, y = y, z = z, allyTeamID = allyTeamID }
			return visible[math.floor(x + 0.5) .. ":" .. math.floor(z + 0.5)] == true
		end
	end

	before_each(function()
		losReads = {}
		env.Spring.GetGroundHeight = function()
			return 50
		end
		setVisiblePoints({})
	end)

	local circle = { x = 1000, z = 2000, radius = 100 }
	local rectangle = { x1 = 0, z1 = 0, x2 = 400, z2 = 200 }

	it("declares its type and requires an area and a sensorAllyTeam", function()
		assert.are.same(
			{ type = "LocationRevealed", area = "Area!", sensorAllyTeam = "AllyTeamID!" },
			summarizeSchema(locationRevealed)
		)
	end)

	it("fires when the centre of a circle is in LOS", function()
		local context, fired = newContext()
		setVisiblePoints({ ["1000:2000"] = true })
		onGameFrame(trigger({ area = circle, sensorAllyTeam = SENSOR_ALLY }), "t", context, CHECK_FRAME)
		assert.are.equal(1, fired())
	end)

	it("fires when only a point on the edge of a circle is in LOS", function()
		local context, fired = newContext()
		setVisiblePoints({ ["900:2000"] = true })
		onGameFrame(trigger({ area = circle, sensorAllyTeam = SENSOR_ALLY }), "t", context, CHECK_FRAME)
		assert.are.equal(1, fired())
	end)

	it("fires when only a corner of a rectangle is in LOS", function()
		local context, fired = newContext()
		setVisiblePoints({ ["400:200"] = true })
		onGameFrame(trigger({ area = rectangle, sensorAllyTeam = SENSOR_ALLY }), "t", context, CHECK_FRAME)
		assert.are.equal(1, fired())
	end)

	it("fires when only a point off the centre of a large square is in LOS", function()
		local context, fired = newContext()
		setVisiblePoints({ ["256:768"] = true })
		local square = { x1 = 0, z1 = 0, x2 = 1024, z2 = 1024 }
		onGameFrame(trigger({ area = square, sensorAllyTeam = SENSOR_ALLY }), "t", context, CHECK_FRAME)
		assert.are.equal(1, fired())
	end)

	it("fires for a single point, given as a circle of radius 0, from one LOS read", function()
		local context, fired = newContext()
		setVisiblePoints({ ["1000:2000"] = true })
		local point = { x = 1000, z = 2000, radius = 0 }
		onGameFrame(trigger({ area = point, sensorAllyTeam = SENSOR_ALLY }), "t", context, CHECK_FRAME)
		assert.are.equal(1, fired())
		assert.are.equal(1, #losReads)
	end)

	it("does not fire while no sampled point is in LOS", function()
		local context, fired = newContext()
		onGameFrame(trigger({ area = circle, sensorAllyTeam = SENSOR_ALLY }), "t", context, CHECK_FRAME)
		assert.are.equal(0, fired())
		assert.is_true(#losReads > 0)
	end)

	it("reads LOS for the sensorAllyTeam at ground height", function()
		local context = newContext()
		onGameFrame(trigger({ area = circle, sensorAllyTeam = 1 }), "t", context, CHECK_FRAME)
		-- The centre and the four rim points of a 3x3 grid over the circle's bounds.
		assert.are.equal(5, #losReads)
		for _, read in ipairs(losReads) do
			assert.are.equal(1, read.allyTeamID)
			assert.are.equal(50, read.y)
		end
	end)

	it("reads no LOS between checks", function()
		local context, fired = newContext()
		setVisiblePoints({ ["1000:2000"] = true })
		local t = trigger({ area = circle, sensorAllyTeam = SENSOR_ALLY })
		for frame = 1, CHECK_FRAME - 1 do
			onGameFrame(t, "t", context, frame)
		end
		assert.are.equal(0, #losReads)
		assert.are.equal(0, fired())
	end)

	it("fires once while the area stays in LOS, and again after it leaves and returns", function()
		local context, fired = newContext()
		local t = trigger({ area = circle, sensorAllyTeam = SENSOR_ALLY }, { repeating = true })

		setVisiblePoints({ ["1000:2000"] = true })
		onGameFrame(t, "t", context, CHECK_FRAME)
		onGameFrame(t, "t", context, 2 * CHECK_FRAME)
		assert.are.equal(1, fired())

		setVisiblePoints({})
		onGameFrame(t, "t", context, 3 * CHECK_FRAME)
		setVisiblePoints({ ["1000:2000"] = true })
		onGameFrame(t, "t", context, 4 * CHECK_FRAME)
		assert.are.equal(2, fired())
	end)

	it("fires once it becomes eligible while the area is already in LOS", function()
		local context, fired = newContext()
		local t = trigger({ area = circle, sensorAllyTeam = SENSOR_ALLY })
		setVisiblePoints({ ["1000:2000"] = true })

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
		local t = trigger({ area = circle, sensorAllyTeam = SENSOR_ALLY })
		t.triggered = true
		onGameFrame(t, "t", context, CHECK_FRAME)
		assert.are.equal(0, #losReads)
		assert.are.equal(0, fired())
	end)
end)
