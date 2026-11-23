local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local ConditionContextBuilder = VFS.Include("spec/builders/condition_context_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs and
-- the TransferUnits fence inside its handler.
MissionApiBuilder.new():Install()

env.UnitDefs = { [1] = { name = "armwin" }, [2] = { name = "armsolar" } }

local unitReceived = MissionSpecEnv.include(env, "luarules/mission_api/conditions/unit_received.lua")
local onUnitGiven = unitReceived.callins.UnitGiven

describe("mission_api.conditions.unit_received", function()
	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local context = ConditionContextBuilder.new():WithEnv(env):Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	-- unitID 100 changes from team 1 to team 0. The gadget passes the capture flag it saw in AllowUnitTransfer.
	local function given(trigger, context, unitDefID, opts)
		opts = opts or {}
		GG["MissionAPI"].transferringUnits = opts.transferringUnits
		GG["MissionAPI"].capturingUnits = opts.capturingUnits
		onUnitGiven(
			trigger,
			triggerID,
			context,
			100,
			unitDefID,
			opts.newTeam or 0,
			opts.oldTeam or 1,
			opts.captured == true
		)
		GG["MissionAPI"].transferringUnits = nil
		GG["MissionAPI"].capturingUnits = nil
	end

	it("declares its type and parameters", function()
		assert.are.equal("UnitReceived", unitReceived.type)
		local names = {}
		for _, parameter in ipairs(unitReceived.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.includeUnit)
		assert.is_true(names.excludeUnit)
		assert.is_true(names.oldTeamName)
		assert.is_true(names.newTeamName)
		assert.is_true(names.ignoreMissionActions)
		assert.is_nil(unitReceived.parameters.requiresOneOf)
	end)

	it("fires when a unit is shared to a team", function()
		local context, fired = newContext()
		given(trigger({ includeUnit = { unitDefName = { [1] = true } }, oldTeamName = 1, newTeamName = 0 }), context, 1)
		assert.are.equal(1, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		given(trigger({ includeUnit = { unitDefName = { [1] = true } } }), context, 2) -- unitDefID 2 = armsolar
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		given(trigger({ includeUnit = { unitName = "gift" } }), context, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by oldTeamName, which is the giving team", function()
		local context, fired = newContext()
		given(trigger({ includeUnit = { unitDefName = { [1] = true } }, oldTeamName = 9 }), context, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by newTeamName, which is the receiving team", function()
		local context, fired = newContext()
		given(trigger({ includeUnit = { unitDefName = { [1] = true } }, newTeamName = 9 }), context, 1)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a capture", function()
		local context, fired = newContext()
		given(trigger({ includeUnit = { unitDefName = { [1] = true } } }), context, 1, { captured = true })
		assert.are.equal(0, fired())
	end)

	it("filters mission transfers by default", function()
		local context, fired = newContext()
		given(trigger({ includeUnit = { unitDefName = { [1] = true } } }), context, 1, { transferringUnits = true })
		assert.are.equal(0, fired())
	end)

	it("fires on a mission transfer when ignoreMissionActions is false", function()
		local context, fired = newContext()
		given(
			trigger({ includeUnit = { unitDefName = { [1] = true } }, ignoreMissionActions = false }),
			context,
			1,
			{ transferringUnits = true }
		)
		assert.are.equal(1, fired())
	end)

	it("fires on a mission gift when ignoreMissionActions is false, whatever the engine flag says", function()
		local context, fired = newContext()
		given(
			trigger({ includeUnit = { unitDefName = { [1] = true } }, ignoreMissionActions = false }),
			context,
			1,
			{ transferringUnits = true, captured = true }
		)
		assert.are.equal(1, fired())
	end)

	it("does not fire on a mission capture, even when ignoreMissionActions is false", function()
		local context, fired = newContext()
		given(
			trigger({ includeUnit = { unitDefName = { [1] = true } }, ignoreMissionActions = false }),
			context,
			1,
			{ transferringUnits = true, capturingUnits = true }
		)
		assert.are.equal(0, fired())
	end)
end)
