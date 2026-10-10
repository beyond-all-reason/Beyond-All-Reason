require("spec_helper")

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

-- Mock tracking with a simple in-memory implementation.
local trackedUnitIDs = {}
local trackedUnitNames = {}
GG["MissionAPI"].trackedUnitIDs = trackedUnitIDs
GG["MissionAPI"].trackedUnitNames = trackedUnitNames
GG["MissionAPI"].Modules.Tracking = {
	UntrackUnitName = function(name)
		if trackedUnitIDs[name] == nil then
			return
		end
		for id in pairs(trackedUnitIDs[name]) do
			if trackedUnitNames[id] then
				trackedUnitNames[id][name] = nil
				if next(trackedUnitNames[id]) == nil then
					trackedUnitNames[id] = nil
				end
			end
		end
		trackedUnitIDs[name] = nil
	end,
}

local actions = VFS.Include("luarules/mission_api/actions/units/unname_units.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function clearTracking()
	for k in pairs(trackedUnitIDs) do
		trackedUnitIDs[k] = nil
	end
	for k in pairs(trackedUnitNames) do
		trackedUnitNames[k] = nil
	end
end

local function seedUnit(name, id)
	trackedUnitIDs[name] = trackedUnitIDs[name] or {}
	trackedUnitIDs[name][id] = true
	trackedUnitNames[id] = trackedUnitNames[id] or {}
	trackedUnitNames[id][name] = true
end

describe("mission_api.actions.unname_units", function()

	before_each(clearTracking)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "UnnameUnits",
			unitName = "UnitName!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("removes all units tracked under the given name", function()
			seedUnit("bots", 1)
			seedUnit("bots", 2)
			action.actionFunction("bots")
			assert.is_nil(trackedUnitIDs["bots"])
		end)

		it("removes the name association from the unit ID entries", function()
			seedUnit("scout", 10)
			action.actionFunction("scout")
			assert.is_nil((trackedUnitNames[10] or {})["scout"])
		end)

		it("is a no-op for a name that was never tracked", function()
			assert.has_no.errors(function()
				action.actionFunction("ghost")
			end)
		end)

		it("does not remove other names tracking the same unit", function()
			seedUnit("alpha", 5)
			seedUnit("beta", 5)
			action.actionFunction("alpha")
			assert.is_nil(trackedUnitIDs["alpha"])
			assert.is_true(trackedUnitIDs["beta"][5] == true)
		end)
	end)

end)
