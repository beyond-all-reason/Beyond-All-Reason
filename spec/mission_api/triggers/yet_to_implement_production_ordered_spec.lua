require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

_G.CMD = _G.CMD or {}
_G.CMD.INSERT = 34
_G.CMD.MOVE = 10

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armlab", isFactory = true },
	[2] = { name = "corvp", isFactory = true },
	[10] = { name = "armpw" },
	[11] = { name = "corfast" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local productionOrdered = VFS.Include("luarules/mission_api/triggers/yet_to_implement_production_ordered.lua")
local onUnitCommand = productionOrdered.callins.UnitCommand

describe("mission_api.triggers.yet_to_implement_production_ordered", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	-- unitID/unitDefID/unitTeam describe the factory receiving the order.
	local function order(t, context, cmdID, cmdParams, opts)
		opts = opts or {}
		GG["MissionAPI"].issuingOrders = opts.issuingOrders
		onUnitCommand(
			t,
			triggerID,
			context,
			opts.unitID or 100,
			opts.unitDefID or 1,
			opts.unitTeam or 0,
			cmdID,
			cmdParams
		)
		GG["MissionAPI"].issuingOrders = nil
	end

	it("declares its type and parameters", function()
		assert.are.equal("ProductionOrdered", productionOrdered.type)
		local names, required = {}, {}
		for _, parameter in ipairs(productionOrdered.parameters) do
			names[parameter.name] = true
			if parameter.required then
				required[parameter.name] = true
			end
		end
		assert.is_true(names.buildDefName)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.fromMission)
		assert.are.same({ buildDefName = true }, required)
	end)

	it("does not fire for a non-factory unit", function()
		local context, fired = newContext()
		-- unitDefID 10 = armpw, not a factory
		order(trigger({ buildDefName = "armpw" }), context, -10, nil, { unitDefID = 10 })
		assert.are.equal(0, fired())
	end)

	it("does not fire for a non-build command", function()
		local context, fired = newContext()
		order(trigger({ buildDefName = "armpw" }), context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(0, fired())
	end)

	it("does not fire when the build command does not resolve to a known unitDef", function()
		local context, fired = newContext()
		order(trigger({ buildDefName = "armpw" }), context, -999)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching build order", function()
		local context, fired = newContext()
		order(trigger({ buildDefName = "armpw" }), context, -10) -- build armpw (unitDefID 10)
		assert.are.equal(1, fired())
	end)

	it("fires for a build order inserted into the queue", function()
		local context, fired = newContext()
		order(trigger({ buildDefName = "armpw" }), context, CMD.INSERT, { 0, -10, 0 })
		assert.are.equal(1, fired())
	end)

	it("filters by buildDefName", function()
		local context, fired = newContext()
		order(trigger({ buildDefName = "corfast" }), context, -10) -- -10 builds armpw
		assert.are.equal(0, fired())
	end)

	it("filters by unitName (the ordered factory's name)", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		order(trigger({ buildDefName = "armpw", unitName = "mainlab" }), context, -10)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName (the factory's own def)", function()
		local context, fired = newContext()
		order(trigger({ buildDefName = "armpw", unitDefName = "corvp" }), context, -10) -- factory is armlab (unitDefID 1)
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		order(trigger({ buildDefName = "armpw", teamID = 9 }), context, -10)
		assert.are.equal(0, fired())
	end)

	it("filters mission-issued orders by default", function()
		local context, fired = newContext()
		order(trigger({ buildDefName = "armpw" }), context, -10, nil, { issuingOrders = true })
		assert.are.equal(0, fired())
	end)

	it("fires on mission-issued orders when fromMission is true", function()
		local context, fired = newContext()
		order(trigger({ buildDefName = "armpw", fromMission = true }), context, -10, nil, { issuingOrders = true })
		assert.are.equal(1, fired())
	end)
end)
