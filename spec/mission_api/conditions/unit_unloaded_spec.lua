local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local ConditionContextBuilder = VFS.Include("spec/builders/condition_context_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs inside its handler.
MissionApiBuilder.new():Install()

env.UnitDefs = {
	[1] = { name = "armpw", isTransport = false },
	[2] = { name = "armck", isTransport = false },
	[10] = { name = "armatlas", isTransport = true },
	[11] = { name = "corvalk", isTransport = true },
	[20] = { name = "armdronecarryland", isTransport = false },
}

local unitUnloaded = MissionSpecEnv.include(env, "luarules/mission_api/conditions/unit_unloaded.lua")
local onUnitUnloaded = unitUnloaded.callins.UnitUnloaded

describe("mission_api.conditions.unit_unloaded", function()
	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local context = ConditionContextBuilder.new():WithEnv(env):Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	-- unitID 100 is the passenger and unitID 50 the transport; the gadget resolves the transport's defID.
	local function unloaded(trigger, context, unitDefID, unitTeam, transportDefID)
		onUnitUnloaded(trigger, triggerID, context, 100, unitDefID, unitTeam, 50, transportDefID or 10)
	end

	it("declares its type and parameters", function()
		assert.are.equal("UnitUnloaded", unitUnloaded.type)
		local names = {}
		for _, parameter in ipairs(unitUnloaded.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.includeUnit)
		assert.is_true(names.excludeUnit)
		assert.is_true(names.transportName)
		assert.is_true(names.transportDefName)
		assert.is_nil(unitUnloaded.parameters.requiresOneOf)
	end)

	it("fires when a unit is unloaded from a transport", function()
		local context, fired = newContext()
		unloaded(trigger({ includeUnit = { unitDefName = { [1] = true }, teamName = 0 } }), context, 1, 0)
		assert.are.equal(1, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		unloaded(trigger({ includeUnit = { unitDefName = { [1] = true } } }), context, 2, 0) -- unitDefID 2 = armck
		assert.are.equal(0, fired())
	end)

	it("filters by teamName, which is the passenger's team", function()
		local context, fired = newContext()
		unloaded(trigger({ includeUnit = { unitDefName = { [1] = true }, teamName = 9 } }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		unloaded(trigger({ includeUnit = { unitName = "passenger" } }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by transportName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function(unitID)
			return unitID == 100 -- the passenger has the name, the transport does not
		end
		unloaded(trigger({ includeUnit = { unitName = "passenger" }, transportName = "dropship" }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by transportDefName", function()
		local context, fired = newContext()
		unloaded(
			trigger({ includeUnit = { unitDefName = { [1] = true } }, transportDefName = "corvalk" }),
			context,
			1,
			0,
			10
		) -- 10 = armatlas
		assert.are.equal(0, fired())
		unloaded(
			trigger({ includeUnit = { unitDefName = { [1] = true } }, transportDefName = "corvalk" }),
			context,
			1,
			0,
			11
		)
		assert.are.equal(1, fired())
	end)

	-- Spring.UnitDetach raises UnitUnloaded for undocking drones and detached turrets.
	it("does not fire when the unloader is not a transport, even when named", function()
		local context, fired = newContext()
		unloaded(trigger({ includeUnit = { unitDefName = { [1] = true } } }), context, 1, 0, 20) -- 20 = a drone carrier
		unloaded(
			trigger({ includeUnit = { unitDefName = { [1] = true } }, transportDefName = "armdronecarryland" }),
			context,
			1,
			0,
			20
		)
		assert.are.equal(0, fired())
	end)
end)
