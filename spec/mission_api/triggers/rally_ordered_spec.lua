require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

_G.CMD = _G.CMD or {}
_G.CMD.INSERT = 34
_G.CMD.MOVE = 10
_G.CMD.RECLAIM = 90
_G.CMD.ANY = "a"
_G.CMD.BUILD = "b"

_G.UnitDefs = {
	[1] = { name = "armlab", isFactory = true },
	[2] = { name = "corfast" },
}

-- VFS.Include caches source text, not results, so this re-runs the trigger file and captures the `CMD` values set above.
local rallyOrdered = VFS.Include("luarules/mission_api/triggers/rally_ordered.lua")
local onUnitCommand = rallyOrdered.callins.UnitCommand

describe("mission_api.triggers.rally_ordered", function()
	before_each(function()
		-- By default the factory does not queue this command (it consumes it, so it's not a rally order),
		-- unless a test overrides FindUnitCmdDesc/GetUnitCmdDescs.
		Spring.FindUnitCmdDesc = function()
			return nil
		end
		Spring.GetUnitCmdDescs = function()
			return { { queueing = false } }
		end
	end)

	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			DoesUnitHaveName = function()
				return true
			end,
			ActivateTrigger = function()
				fired = fired + 1
			end,
		}
		return context, function()
			return fired
		end
	end

	local triggerID = "t"

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
		assert.are.equal("RallyOrdered", rallyOrdered.type)
		local names, required = {}, {}
		for _, parameter in ipairs(rallyOrdered.parameters) do
			names[parameter.name] = true
			if parameter.required then
				required[parameter.name] = true
			end
		end
		assert.is_true(names.command)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.fromMission)
		assert.are.same({ command = true }, required)
		assert.are.same({ "unitName", "unitDefName" }, rallyOrdered.parameters.requiresOneOf)
	end)

	it("does not fire for a non-factory unit", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = "corfast" }), context, CMD.MOVE, { 0, 0, 0 }, {
			unitDefID = 2,
		})
		assert.are.equal(0, fired())
	end)

	it("filters by command", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = "armlab" }), context, CMD.RECLAIM, { 1, 2, 3, 4 })
		assert.are.equal(0, fired())
	end)

	it("does not fire when the factory itself executes the command", function()
		local context, fired = newContext()
		Spring.FindUnitCmdDesc = function()
			return 1
		end
		Spring.GetUnitCmdDescs = function()
			return { { queueing = false } }
		end
		order(trigger({ command = CMD.MOVE, unitDefName = "armlab" }), context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(0, fired())
	end)

	it("fires when the factory relays the command as a rally order", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = "armlab" }), context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(1, fired())
	end)

	it("fires on a rally order inserted into the queue", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = "armlab" }), context, CMD.INSERT, { 0, CMD.MOVE, 0, 0, 0, 0 })
		assert.are.equal(1, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		order(trigger({ command = CMD.MOVE, unitName = "factory" }), context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		-- unitDefID 1 = armlab
		order(trigger({ command = CMD.MOVE, unitDefName = "corfast" }), context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = "armlab", teamID = 9 }), context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(0, fired())
	end)

	it("fires on any relayed command when command is CMD.ANY", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.ANY, unitDefName = "armlab" }), context, CMD.RECLAIM, { 1, 2, 3, 4 })
		assert.are.equal(1, fired())
	end)

	it("filters mission-issued orders by default", function()
		local context, fired = newContext()
		order(
			trigger({ command = CMD.MOVE, unitDefName = "armlab" }),
			context,
			CMD.MOVE,
			{ 0, 0, 0 },
			{ issuingOrders = true }
		)
		assert.are.equal(0, fired())
	end)

	it("fires on mission-issued orders when fromMission is true", function()
		local context, fired = newContext()
		order(
			trigger({ command = CMD.MOVE, unitDefName = "armlab", fromMission = true }),
			context,
			CMD.MOVE,
			{ 0, 0, 0 },
			{ issuingOrders = true }
		)
		assert.are.equal(1, fired())
	end)
end)
