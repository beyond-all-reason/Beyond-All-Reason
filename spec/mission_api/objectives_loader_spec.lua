require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local ObjectivesLoader = VFS.Include("luarules/mission_api/objectives_loader.lua")
local ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua").Types

-- Stand-in definitions: two observer types, one of them naming its ObjectiveID
-- parameter differently, and one type that does not watch objectives.
local TYPES = { Watch = 1, Other = 2, Plain = 3 }
local DEFINITIONS = {
	Types = TYPES,
	Parameters = {
		[TYPES.Watch] = { { name = "objectiveID", required = true, type = ParameterTypes.ObjectiveID } },
		[TYPES.Other] = { { name = "target", required = true, type = ParameterTypes.ObjectiveID } },
		[TYPES.Plain] = { { name = "seconds", required = true, type = ParameterTypes.Number } },
	},
}

describe("mission_api.objectives_loader", function()
	describe("ProcessObjectiveObservers", function()
		local function index(triggers)
			Builders.MissionApi.new():WithTriggerDefinitions(DEFINITIONS):Install()
			return ObjectivesLoader.ProcessObjectiveObservers(triggers)
		end

		it("groups observer triggers by objective ID, then by trigger type", function()
			local triggers = {
				watchA = { type = TYPES.Watch, parameters = { objectiveID = "obj1" } },
				watchB = { type = TYPES.Watch, parameters = { objectiveID = "obj1" } },
				watchC = { type = TYPES.Watch, parameters = { objectiveID = "obj2" } },
			}

			local observers = index(triggers)

			assert.are.equal(2, #observers.obj1[TYPES.Watch])
			assert.are.equal(1, #observers.obj2[TYPES.Watch])
			assert.are.equal(triggers.watchC, observers.obj2[TYPES.Watch][1])
		end)

		it("reads the objective ID from whatever the type names its ObjectiveID parameter", function()
			local triggers = {
				other = { type = TYPES.Other, parameters = { target = "obj1" } },
			}

			local observers = index(triggers)

			assert.are.equal(triggers.other, observers.obj1[TYPES.Other][1])
			assert.is_nil(observers.obj1[TYPES.Watch])
		end)

		it("ignores trigger types without an ObjectiveID parameter", function()
			local triggers = {
				plain = { type = TYPES.Plain, parameters = { seconds = 3, objectiveID = "obj1" } },
			}

			assert.are.same({}, index(triggers))
		end)

		it("returns an empty index for a mission without observers", function()
			assert.are.same({}, index({}))
		end)
	end)
end)
