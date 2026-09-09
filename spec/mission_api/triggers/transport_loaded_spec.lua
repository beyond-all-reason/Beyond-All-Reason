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

local transportLoaded = VFS.Include("luarules/mission_api/triggers/transport_loaded.lua")
local onUnitLoaded = transportLoaded.callins.UnitLoaded

describe("mission_api.triggers.transport_loaded", function()
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
	local function loaded(trigger, context, transportDefID, transportTeam, unitDefID)
		onUnitLoaded(trigger, triggerID, context, 100, unitDefID or 1, 0, 50, transportDefID, transportTeam)
	end

	it("declares its type and parameters", function()
		assert.are.equal("TransportLoaded", transportLoaded.type)
		local names = {}
		for _, parameter in ipairs(transportLoaded.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.transportName)
		assert.is_true(names.transportDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.passengerName)
		assert.is_true(names.passengerDefName)
		assert.are.same({ "transportName", "transportDefName" }, transportLoaded.parameters.requiresOneOf)
	end)

	it("fires when a transport loads a unit", function()
		local context, fired = newContext()
		loaded(trigger({ transportDefName = "armatlas", teamID = 0 }), context, 10, 0)
		assert.are.equal(1, fired())
	end)

	it("filters by transportDefName", function()
		local context, fired = newContext()
		loaded(trigger({ transportDefName = "corvalk" }), context, 10, 0) -- 10 = armatlas
		assert.are.equal(0, fired())
	end)

	it("filters by teamID, which is the transport's team", function()
		local context, fired = newContext()
		loaded(trigger({ transportDefName = "armatlas", teamID = 9 }), context, 10, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by transportName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		loaded(trigger({ transportName = "dropship" }), context, 10, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by passengerName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function(unitID)
			return unitID == 50 -- the transport has the name, the passenger does not
		end
		loaded(trigger({ transportName = "dropship", passengerName = "passenger" }), context, 10, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by passengerDefName", function()
		local context, fired = newContext()
		loaded(trigger({ transportDefName = "armatlas", passengerDefName = "armck" }), context, 10, 0, 1) -- 1 = armpw
		assert.are.equal(0, fired())
		loaded(trigger({ transportDefName = "armatlas", passengerDefName = "armck" }), context, 10, 0, 2)
		assert.are.equal(1, fired())
	end)

	-- Spring.UnitAttach raises UnitLoaded for docking drones, hats, and attached turrets.
	it("fires for a loader that is not a transport when named by definition", function()
		local context, fired = newContext()
		loaded(trigger({ transportDefName = "armdronecarryland" }), context, 20, 0)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a loader that is not a transport when named by unit name alone", function()
		local context, fired = newContext()
		loaded(trigger({ transportName = "carrier" }), context, 20, 0)
		assert.are.equal(0, fired())
	end)
end)
