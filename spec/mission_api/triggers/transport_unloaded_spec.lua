require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and UnitDefs inside its handler.
Builders.MissionApi.new():Install()

_G.UnitDefs = {
	[1] = { name = "armpw", isTransport = false },
	[2] = { name = "armck", isTransport = false },
	[10] = { name = "armatlas", isTransport = true },
	[11] = { name = "corvalk", isTransport = true },
	[20] = { name = "armdronecarryland", isTransport = false },
}

local transportUnloaded = VFS.Include("luarules/mission_api/triggers/transport_unloaded.lua")
local onUnitUnloaded = transportUnloaded.callins.UnitUnloaded

describe("mission_api.triggers.transport_unloaded", function()
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

	-- unitID 100 is the passenger and unitID 50 the transport; the gadget resolves the transport's defID.
	local function unloaded(trigger, context, transportDefID, transportTeam, unitDefID)
		onUnitUnloaded(trigger, triggerID, context, 100, unitDefID or 1, 0, 50, transportDefID, transportTeam)
	end

	it("declares its type and parameters", function()
		assert.are.equal("TransportUnloaded", transportUnloaded.type)
		local names = {}
		for _, parameter in ipairs(transportUnloaded.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.transportName)
		assert.is_true(names.transportDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.are.same({ "transportName", "transportDefName" }, transportUnloaded.parameters.requiresOneOf)
	end)

	it("fires when a transport unloads a unit", function()
		local context, fired = newContext()
		unloaded(trigger({ transportDefName = "armatlas", teamID = 0 }), context, 10, 0)
		assert.are.equal(1, fired())
	end)

	it("filters by transportDefName", function()
		local context, fired = newContext()
		unloaded(trigger({ transportDefName = "corvalk" }), context, 10, 0) -- 10 = armatlas
		assert.are.equal(0, fired())
	end)

	it("filters by teamID, which is the transport's team", function()
		local context, fired = newContext()
		unloaded(trigger({ transportDefName = "armatlas", teamID = 9 }), context, 10, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by transportName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		unloaded(trigger({ transportName = "dropship" }), context, 10, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function(unitID)
			return unitID == 50 -- the transport has the name, the passenger does not
		end
		unloaded(trigger({ transportName = "dropship", unitName = "passenger" }), context, 10, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		unloaded(trigger({ transportDefName = "armatlas", unitDefName = "armck" }), context, 10, 0, 1) -- 1 = armpw
		assert.are.equal(0, fired())
		unloaded(trigger({ transportDefName = "armatlas", unitDefName = "armck" }), context, 10, 0, 2)
		assert.are.equal(1, fired())
	end)

	-- Spring.UnitDetach raises UnitUnloaded for undocking drones and detached turrets.
	it("fires for an unloader that is not a transport when named by definition", function()
		local context, fired = newContext()
		unloaded(trigger({ transportDefName = "armdronecarryland" }), context, 20, 0)
		assert.are.equal(1, fired())
	end)

	it("does not fire for an unloader that is not a transport when named by unit name alone", function()
		local context, fired = newContext()
		unloaded(trigger({ transportName = "carrier" }), context, 20, 0)
		assert.are.equal(0, fired())
	end)
end)
