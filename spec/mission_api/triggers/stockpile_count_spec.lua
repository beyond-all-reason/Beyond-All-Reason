local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local NUKE = 10
local GUN = 11

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armsilo", weapons = { { weaponDef = NUKE } } },
	[2] = { name = "corsilo", weapons = { { weaponDef = NUKE } } },
	[3] = { name = "armwar", weapons = { { weaponDef = GUN } } },
})

local env = MissionSpecEnv.new({
	UnitDefs = unitDefs:GetUnitDefsByID(),
	WeaponDefs = {
		[NUKE] = { name = "nuclear_missile", stockpile = true },
		[GUN] = { name = "emg", stockpile = false },
	},
})

Builders.MissionApi.new():Install()

local stockpileCount = MissionSpecEnv.include(env, "luarules/mission_api/triggers/stockpile_count.lua")
local onStockpileChanged = stockpileCount.callins.StockpileChanged

describe("mission_api.triggers.stockpile_count", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local function changed(t, context, unitID, unitDefID, oldCount, newCount)
		onStockpileChanged(t, "t", context, unitID, unitDefID, 0, 1, oldCount, newCount)
	end

	it("declares its type and parameters", function()
		assert.are.equal("StockpileCount", stockpileCount.type)
		local required = {}
		for _, parameter in ipairs(stockpileCount.parameters) do
			required[parameter.name] = parameter.required
		end
		assert.are.same({ count = true, unitName = false, unitDefName = false, teamID = false }, required)
	end)

	it("fires when the count rises to the threshold", function()
		local context, fired = newContext()
		local t = trigger({ count = 2 })
		changed(t, context, 100, 1, 0, 1)
		assert.are.equal(0, fired())
		changed(t, context, 100, 1, 1, 2)
		assert.are.equal(1, fired())
	end)

	it("fires again when a fired item is restocked to the threshold", function()
		local context, fired = newContext()
		local t = trigger({ count = 2 })
		changed(t, context, 100, 1, 1, 2)
		changed(t, context, 100, 1, 2, 1)
		changed(t, context, 100, 1, 1, 2)
		assert.are.equal(2, fired())
	end)

	it("does not fire when the count falls to the threshold", function()
		local context, fired = newContext()
		changed(trigger({ count = 2 }), context, 100, 1, 3, 2)
		assert.are.equal(0, fired())
	end)

	it("does not fire when the count rises above the threshold", function()
		local context, fired = newContext()
		changed(trigger({ count = 2 }), context, 100, 1, 2, 3)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		local t = trigger({ count = 1, unitDefName = "armsilo" })
		changed(t, context, 100, 2, 0, 1)
		assert.are.equal(0, fired())
		changed(t, context, 101, 1, 0, 1)
		assert.are.equal(1, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function(unitID, name)
			return unitID == 101 and name == "silo"
		end
		local t = trigger({ count = 1, unitName = "silo" })
		changed(t, context, 100, 1, 0, 1)
		assert.are.equal(0, fired())
		changed(t, context, 101, 1, 0, 1)
		assert.are.equal(1, fired())
	end)
end)
