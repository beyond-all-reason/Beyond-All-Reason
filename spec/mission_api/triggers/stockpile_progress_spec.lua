local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local NUKE = 10
local GUN = 11
local POLL_FRAMES = 15

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

local stockpileProgress = MissionSpecEnv.include(env, "luarules/mission_api/triggers/stockpile_progress.lua")
local callins = stockpileProgress.callins

describe("mission_api.triggers.stockpile_progress", function()
	local progressByUnit ---@type table<integer, number>
	local frame ---@type integer

	before_each(function()
		progressByUnit = {}
		frame = 0
		env.Spring.GetUnitStockpile = function(unitID)
			local progress = progressByUnit[unitID] ---@type number?
			if progress then
				return 0, 1, progress
			end
		end
	end)

	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local function added(t, context, unitID, unitDefID, progress)
		progressByUnit[unitID] = progress or 0
		callins.MetaUnitAdded(t, "t", context, unitID, unitDefID)
	end

	local function removed(t, context, unitID)
		progressByUnit[unitID] = nil
		callins.MetaUnitRemoved(t, "t", context, unitID)
	end

	local function completed(t, context, unitID, unitDefID)
		callins.StockpileChanged(t, "t", context, unitID, unitDefID, 0, 1, 0, 1)
	end

	-- Advances to the next poll with the unit's progress at the given value.
	local function poll(t, context, unitID, progress)
		progressByUnit[unitID] = progress
		frame = frame + POLL_FRAMES
		callins.GameFrame(t, "t", context, frame)
	end

	it("declares its type and parameters", function()
		assert.are.equal("StockpileProgress", stockpileProgress.type)
		local required = {}
		for _, parameter in ipairs(stockpileProgress.parameters) do
			required[parameter.name] = parameter.required
		end
		assert.are.same({ progress = true, unitName = false, unitDefName = false }, required)
	end)

	it("fires when the progress crosses the threshold", function()
		local context, fired = newContext()
		local t = trigger({ progress = 0.5 })
		added(t, context, 100, 1)
		poll(t, context, 100, 0.3)
		assert.are.equal(0, fired())
		poll(t, context, 100, 0.6)
		assert.are.equal(1, fired())
		poll(t, context, 100, 0.8)
		assert.are.equal(1, fired())
	end)

	it("reads the progress only on poll frames", function()
		local context, fired = newContext()
		local t = trigger({ progress = 0.5 })
		added(t, context, 100, 1)
		progressByUnit[100] = 0.6
		callins.GameFrame(t, "t", context, POLL_FRAMES - 1)
		assert.are.equal(0, fired())
		callins.GameFrame(t, "t", context, POLL_FRAMES)
		assert.are.equal(1, fired())
	end)

	it("fires for an item that completed between polls from below the threshold", function()
		local context, fired = newContext()
		local t = trigger({ progress = 0.5 })
		added(t, context, 100, 1, 0.3)
		completed(t, context, 100, 1)
		poll(t, context, 100, 0.1)
		assert.are.equal(1, fired())
	end)

	it("fires twice when the next item also passes the threshold before the poll", function()
		local context, fired = newContext()
		local t = trigger({ progress = 0.5 })
		added(t, context, 100, 1, 0.3)
		completed(t, context, 100, 1)
		poll(t, context, 100, 0.6)
		assert.are.equal(2, fired())
	end)

	it("does not fire again for an item it fired for before it completed", function()
		local context, fired = newContext()
		local t = trigger({ progress = 0.5 })
		added(t, context, 100, 1, 0.3)
		poll(t, context, 100, 0.6)
		completed(t, context, 100, 1)
		poll(t, context, 100, 0.1)
		assert.are.equal(1, fired())
	end)

	it("tracks only units that can stockpile", function()
		local context, fired = newContext()
		local t = trigger({ progress = 0.5 })
		added(t, context, 100, 3)
		poll(t, context, 100, 0.6)
		assert.are.equal(0, fired())
		assert.is_nil(context.StockpileState.t)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		local t = trigger({ progress = 0.5, unitDefName = "armsilo" })
		added(t, context, 100, 2)
		poll(t, context, 100, 0.6)
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		local t = trigger({ progress = 0.5, unitName = "silo" })
		added(t, context, 100, 1)
		poll(t, context, 100, 0.6)
		assert.are.equal(0, fired())
	end)

	it("forgets a unit once it is removed", function()
		local context, fired = newContext()
		local t = trigger({ progress = 0.5 })
		added(t, context, 100, 1)
		removed(t, context, 100)
		assert.is_nil(context.StockpileState.t)
		poll(t, context, 100, 0.6)
		assert.are.equal(0, fired())
	end)
end)
