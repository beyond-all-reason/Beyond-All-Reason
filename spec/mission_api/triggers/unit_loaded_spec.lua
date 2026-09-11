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

local unitLoaded = VFS.Include("luarules/mission_api/triggers/unit_loaded.lua")
local onUnitLoaded = unitLoaded.callins.UnitLoaded

describe("mission_api.triggers.unit_loaded", function()
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
	local function loaded(trigger, context, unitDefID, unitTeam, transportDefID)
		onUnitLoaded(trigger, triggerID, context, 100, unitDefID, unitTeam, 50, transportDefID or 10)
	end

	it("declares its type and parameters", function()
		assert.are.equal("UnitLoaded", unitLoaded.type)
		local names = {}
		for _, parameter in ipairs(unitLoaded.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.passengerName)
		assert.is_true(names.passengerDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.transportName)
		assert.is_true(names.transportDefName)
		assert.are.same({ "passengerName", "passengerDefName" }, unitLoaded.parameters.requiresOneOf)
	end)

	it("fires when a unit is loaded into a transport", function()
		local context, fired = newContext()
		loaded(trigger({ passengerDefName = "armpw", teamID = 0 }), context, 1, 0)
		assert.are.equal(1, fired())
	end)

	it("filters by passengerDefName", function()
		local context, fired = newContext()
		loaded(trigger({ passengerDefName = "armpw" }), context, 2, 0) -- unitDefID 2 = armck
		assert.are.equal(0, fired())
	end)

	it("filters by teamID, which is the passenger's team", function()
		local context, fired = newContext()
		loaded(trigger({ passengerDefName = "armpw", teamID = 9 }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by passengerName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		loaded(trigger({ passengerName = "passenger" }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by transportName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function(unitID)
			return unitID == 100 -- the passenger has the name, the transport does not
		end
		loaded(trigger({ passengerName = "passenger", transportName = "dropship" }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by transportDefName", function()
		local context, fired = newContext()
		loaded(trigger({ passengerDefName = "armpw", transportDefName = "corvalk" }), context, 1, 0, 10) -- 10 = armatlas
		assert.are.equal(0, fired())
		loaded(trigger({ passengerDefName = "armpw", transportDefName = "corvalk" }), context, 1, 0, 11)
		assert.are.equal(1, fired())
	end)

	-- Spring.UnitAttach raises UnitLoaded for docking drones, hats, and attached turrets.
	it("does not fire when the loader is not a transport, even when named", function()
		local context, fired = newContext()
		loaded(trigger({ passengerDefName = "armpw" }), context, 1, 0, 20) -- 20 = a drone carrier
		loaded(trigger({ passengerDefName = "armpw", transportDefName = "armdronecarryland" }), context, 1, 0, 20)
		assert.are.equal(0, fired())
	end)
end)
