require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs and
-- the TransferUnits fence inside its handler.
Builders.MissionApi.new():Install()

_G.UnitDefs = { [1] = { name = "armwin" }, [2] = { name = "armsolar" } }

local unitReceived = VFS.Include("luarules/mission_api/triggers/unit_received.lua")
local onUnitGiven = unitReceived.callins.UnitGiven

describe("mission_api.triggers.unit_received", function()
	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			ActivateTrigger = function()
				fired = fired + 1
			end,
			DoesUnitHaveName = function()
				return true
			end,
		}
		return context, function()
			return fired
		end
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
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.oldTeamID)
		assert.is_true(names.newTeamID)
		assert.is_true(names.ignoreMissionActions)
		assert.are.same({ "unitName", "unitDefName" }, unitReceived.parameters.requiresOneOf)
	end)

	it("fires when a unit is shared to a team", function()
		local context, fired = newContext()
		given(trigger({ unitDefName = "armwin", oldTeamID = 1, newTeamID = 0 }), context, 1)
		assert.are.equal(1, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		given(trigger({ unitDefName = "armwin" }), context, 2) -- unitDefID 2 = armsolar
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		given(trigger({ unitName = "gift" }), context, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by oldTeamID, which is the giving team", function()
		local context, fired = newContext()
		given(trigger({ unitDefName = "armwin", oldTeamID = 9 }), context, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by newTeamID, which is the receiving team", function()
		local context, fired = newContext()
		given(trigger({ unitDefName = "armwin", newTeamID = 9 }), context, 1)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a capture", function()
		local context, fired = newContext()
		given(trigger({ unitDefName = "armwin" }), context, 1, { captured = true })
		assert.are.equal(0, fired())
	end)

	it("filters mission transfers by default", function()
		local context, fired = newContext()
		given(trigger({ unitDefName = "armwin" }), context, 1, { transferringUnits = true })
		assert.are.equal(0, fired())
	end)

	it("fires on a mission transfer when ignoreMissionActions is false", function()
		local context, fired = newContext()
		given(
			trigger({ unitDefName = "armwin", ignoreMissionActions = false }),
			context,
			1,
			{ transferringUnits = true }
		)
		assert.are.equal(1, fired())
	end)

	it("fires on a mission gift when ignoreMissionActions is false, whatever the engine flag says", function()
		local context, fired = newContext()
		given(
			trigger({ unitDefName = "armwin", ignoreMissionActions = false }),
			context,
			1,
			{ transferringUnits = true, captured = true }
		)
		assert.are.equal(1, fired())
	end)

	it("does not fire on a mission capture, even when ignoreMissionActions is false", function()
		local context, fired = newContext()
		given(
			trigger({ unitDefName = "armwin", ignoreMissionActions = false }),
			context,
			1,
			{ transferringUnits = true, capturingUnits = true }
		)
		assert.are.equal(0, fired())
	end)
end)
