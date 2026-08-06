require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.CMD = _G.CMD or {}
_G.CMD.INSERT  = 34
_G.CMD.MOVE    = 10
_G.CMD.RECLAIM = 90
_G.CMD.ANY     = 'a'
_G.CMD.BUILD   = 'b'

_G.UnitDefs = { [1] = { name = 'armpw' }, [2] = { name = 'corfast' } }

-- Another spec caches this trigger (via LoadTriggerDefinitions) while `CMD` is _empty_.
-- Drop it from the cache to force a fresh load that can capture `CMD.INSERT` set above.
_G.VFS._cache['luarules/mission_api/triggers/unit_ordered.lua'] = nil
local unitOrdered = VFS.Include('luarules/mission_api/triggers/unit_ordered.lua')
local onUnitCommand = unitOrdered.callins.UnitCommand

describe("mission_api.triggers.unit_ordered", function()
	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			DoesUnitHaveName = function() return true end,
			ActivateTrigger = function() fired = fired + 1 end,
		}
		return context, function() return fired end
	end

	local triggerID = 't'

	local function order(t, context, cmdID, cmdParams, opts)
		opts = opts or {}
		GG['MissionAPI'].issuingOrders = opts.issuingOrders
		onUnitCommand(t, triggerID, context, opts.unitID or 100, opts.unitDefID or 1, opts.unitTeam or 0, cmdID, cmdParams)
		GG['MissionAPI'].issuingOrders = nil
	end

	it("declares its type and parameters", function()
		assert.are.equal('UnitOrdered', unitOrdered.type)
		local names, required = {}, {}
		for _, parameter in ipairs(unitOrdered.parameters) do
			names[parameter.name] = true
			if parameter.required then required[parameter.name] = true end
		end
		assert.is_true(names.command)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.fromMission)
		assert.are.same({ command = true }, required)
		assert.are.same({ 'unitName', 'unitDefName' }, unitOrdered.parameters.requiresOneOf)
	end)

	it("filters by command", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = 'armpw' }), context, CMD.RECLAIM, { 1, 2, 3, 4 })
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function() return false end
		order(trigger({ command = CMD.MOVE, unitName = 'scouts' }), context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = 'corfast' }), context, CMD.MOVE, { 0, 0, 0 }) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = 'armpw', teamID = 9 }), context, CMD.MOVE, { 0, 0, 0 }) -- unitTeam 0
		assert.are.equal(0, fired())
	end)

	it("fires when a matching unit receives the command", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = 'armpw' }), context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(1, fired())
	end)

	it("fires on a command inserted into the queue", function()
		-- Packed insert params: { insertIndex, innerCmdID, innerCodedOptions, ...innerParams }
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = 'armpw' }), context, CMD.INSERT, { 0, CMD.MOVE, 0, 0, 0, 0 })
		assert.are.equal(1, fired())
	end)

	it("filters by command through a queue insertion", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = 'armpw' }), context, CMD.INSERT, { 0, CMD.RECLAIM, 0, 1, 2, 3, 4 })
		assert.are.equal(0, fired())
	end)

	it("matches a build order by its command id", function()
		-- A build order for corfast (unitDefID 2) is command -2 after processing.
		local context, fired = newContext()
		order(trigger({ command = -2, unitDefName = 'armpw' }), context, -2, { 100, 0, 200 })
		assert.are.equal(1, fired())
	end)

	it("fires on any command when command is CMD.ANY", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.ANY, unitDefName = 'armpw' }), context, CMD.RECLAIM, { 1, 2, 3, 4 })
		assert.are.equal(1, fired())
	end)

	it("fires on any build order when command is CMD.BUILD", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.BUILD, unitDefName = 'armpw' }), context, -2, { 100, 0, 200 })
		assert.are.equal(1, fired())
	end)

	it("filters non-build commands when command is CMD.BUILD", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.BUILD, unitDefName = 'armpw' }), context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(0, fired())
	end)

	it("fires on a build order inserted into the queue when command is CMD.BUILD", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.BUILD, unitDefName = 'armpw' }), context, CMD.INSERT, { 0, -2, 0, 100, 0, 200 })
		assert.are.equal(1, fired())
	end)

	it("filters mission-issued orders by default", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = 'armpw' }), context, CMD.MOVE, { 0, 0, 0 }, { issuingOrders = true })
		assert.are.equal(0, fired())
	end)

	it("fires on mission-issued orders when fromMission is true", function()
		local context, fired = newContext()
		order(trigger({ command = CMD.MOVE, unitDefName = 'armpw', fromMission = true }), context, CMD.MOVE, { 0, 0, 0 }, { issuingOrders = true })
		assert.are.equal(1, fired())
	end)

	it("re-fires on every order, with no deduplication", function()
		local context, fired = newContext()
		local t = trigger({ command = CMD.MOVE, unitDefName = 'armpw' })
		order(t, context, CMD.MOVE, { 0, 0, 0 })
		order(t, context, CMD.MOVE, { 0, 0, 0 })
		order(t, context, CMD.MOVE, { 0, 0, 0 })
		assert.are.equal(3, fired())
	end)
end)
