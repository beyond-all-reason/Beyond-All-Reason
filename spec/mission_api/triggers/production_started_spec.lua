require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- Spring.GetUnitIsBeingBuilt / Spring.GetUnitDefID / UnitDefs inside its handler.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

-- Builder ids double as their own defIDs below, so UnitDefs is keyed by both. Maybe too confusing.
_G.UnitDefs = {
	[1] = { name = "armpw" },
	[2] = { name = "armck" },
	[10] = { name = "armlab", isFactory = true },
	[11] = { name = "armvp", isFactory = true },
	[20] = { name = "armck" }, -- a constructor, so an open-field build frame
}

local productionStarted = VFS.Include("luarules/mission_api/triggers/production_started.lua")
local onUnitCreated = productionStarted.callins.UnitCreated

describe("mission_api.triggers.production_started", function()
	before_each(function()
		-- Default: a factory just put its buildee on the build pad.
		Spring.GetUnitIsBeingBuilt = function()
			return true
		end
		Spring.GetUnitDefID = function(unitID)
			return unitID
		end
	end)

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

	-- unitID 100 is the buildee
	-- builderID carries the factory's defID anyway so this is double-used; see GetUnitDefID above.
	local function produced(trigger, context, unitDefID, unitTeam, builderID)
		onUnitCreated(trigger, triggerID, context, 100, unitDefID, unitTeam, builderID)
	end

	it("declares its type and parameters", function()
		assert.are.equal("ProductionStarted", productionStarted.type)
		local names = {}
		for _, parameter in ipairs(productionStarted.parameters) do
			names[parameter.name] = parameter.required
		end
		assert.is_true(names.unitDefName) -- a buildee has no unitName yet, so this stands in as required
		assert.is_false(names.teamID)
		assert.is_false(names.factoryName)
		assert.is_false(names.factoryDefName)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		produced(trigger({ unitDefName = "armpw" }), context, 2, 0, 10) -- unitDefID 2 = armck
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		produced(trigger({ unitDefName = "armpw", teamID = 0 }), context, 1, 9, 10)
		assert.are.equal(0, fired())
	end)

	it("filters by factoryDefName", function()
		local context, fired = newContext()
		produced(trigger({ unitDefName = "armpw", factoryDefName = "armvp" }), context, 1, 0, 10) -- factory 10 = armlab
		assert.are.equal(0, fired())
		produced(trigger({ unitDefName = "armpw", factoryDefName = "armlab" }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("filters by factoryName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		produced(trigger({ unitDefName = "armpw", factoryName = "botlab" }), context, 1, 0, 10)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching production", function()
		local context, fired = newContext()
		produced(trigger({ unitDefName = "armpw", teamID = 0 }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("fires once per buildee, so a queue of them fires once each", function()
		local context, fired = newContext()
		local watchThePawns = trigger({ unitDefName = "armpw" })
		produced(watchThePawns, context, 1, 0, 10)
		produced(watchThePawns, context, 1, 0, 10)
		assert.are.equal(2, fired())
	end)

	it("does not fire for a build frame placed by a constructor", function()
		local context, fired = newContext()
		produced(trigger({ unitDefName = "armpw" }), context, 1, 0, 20) -- builder 20 = armck
		assert.are.equal(0, fired())
	end)

	it("does not fire for a unit that has no builder", function()
		local context, fired = newContext()
		produced(trigger({ unitDefName = "armpw" }), context, 1, 0, nil)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a unit that is not being built", function()
		Spring.GetUnitIsBeingBuilt = function()
			return false
		end
		local context, fired = newContext()
		produced(trigger({ unitDefName = "armpw" }), context, 1, 0, 10)
		assert.are.equal(0, fired())
	end)
end)
