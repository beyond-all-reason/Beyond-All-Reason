require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs and
-- the TransferUnits fences inside its handler.
Builders.MissionApi.new():Install()

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armpw" },
	[2] = { name = "corfast" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local unitCaptured = VFS.Include("luarules/mission_api/triggers/unit_captured.lua")
local onUnitTaken = unitCaptured.callins.UnitTaken

describe("mission_api.triggers.unit_captured", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	-- unitID 100 changes from team 0 to team 1. The gadget passes the capture flag it saw in
	-- AllowUnitTransfer, which is true here unless the test says otherwise.
	local function taken(trigger, context, unitDefID, opts)
		opts = opts or {}
		GG["MissionAPI"].transferringUnits = opts.transferringUnits
		GG["MissionAPI"].capturingUnits = opts.capturingUnits
		onUnitTaken(
			trigger,
			triggerID,
			context,
			100,
			unitDefID,
			opts.oldTeam or 0,
			opts.newTeam or 1,
			opts.captured ~= false
		)
		GG["MissionAPI"].transferringUnits = nil
		GG["MissionAPI"].capturingUnits = nil
	end

	it("declares its type and parameters", function()
		assert.are.equal("UnitCaptured", unitCaptured.type)
		local names = {}
		for _, parameter in ipairs(unitCaptured.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.oldTeamID)
		assert.is_true(names.newTeamID)
		assert.is_true(names.ignoreMissionActions)
		assert.are.same({ "unitName", "unitDefName" }, unitCaptured.parameters.requiresOneOf)
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		taken(trigger({ unitName = "engineers" }), context, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = "corfast" }), context, 1) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by oldTeamID", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = "armpw", oldTeamID = 5 }), context, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by newTeamID", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = "armpw", newTeamID = 5 }), context, 1)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching capture", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = "armpw", oldTeamID = 0, newTeamID = 1 }), context, 1)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a gift", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = "armpw" }), context, 1, { captured = false })
		assert.are.equal(0, fired())
	end)

	it("filters mission captures by default", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = "armpw" }), context, 1, { transferringUnits = true, capturingUnits = true })
		assert.are.equal(0, fired())
	end)

	it("fires on a mission capture when ignoreMissionActions is false, whatever the engine flag says", function()
		local context, fired = newContext()
		taken(
			trigger({ unitDefName = "armpw", ignoreMissionActions = false }),
			context,
			1,
			{ transferringUnits = true, capturingUnits = true, captured = false }
		)
		assert.are.equal(1, fired())
	end)

	it("does not fire on a mission gift, even when ignoreMissionActions is false", function()
		local context, fired = newContext()
		taken(
			trigger({ unitDefName = "armpw", ignoreMissionActions = false }),
			context,
			1,
			{ transferringUnits = true, captured = true }
		)
		assert.are.equal(0, fired())
	end)
end)
