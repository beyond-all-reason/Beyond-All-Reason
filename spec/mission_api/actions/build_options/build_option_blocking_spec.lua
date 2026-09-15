require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/build_options/build_option_blocking.lua")
local summarizeSchema = require("mission_api.schema_spec_helper")

local function findAction(actionType)
	for _, action in ipairs(actions) do
		if action.type == actionType then
			return action
		end
	end
	error("no action of type " .. actionType)
end

local disableAction = findAction("DisableBuildOption")
local enableAction = findAction("EnableBuildOption")

describe("mission_api.actions.build_option_blocking", function()

	local calls

	before_each(function()
		calls = { add = {}, remove = {} }
		GG["BuildBlocking"] = {
			AddBlockedUnit = function(unitDefID, teamID, reasonKey, builderUnitDefID)
				calls.add[#calls.add + 1] = {
					unitDefID = unitDefID,
					teamID = teamID,
					reasonKey = reasonKey,
					builderUnitDefID = builderUnitDefID,
				}
			end,
			RemoveBlockedUnit = function(unitDefID, teamID, reasonKey, builderUnitDefID)
				calls.remove[#calls.remove + 1] = {
					unitDefID = unitDefID,
					teamID = teamID,
					reasonKey = reasonKey,
					builderUnitDefID = builderUnitDefID,
				}
				return true
			end,
		}
	end)

	after_each(function()
		GG["BuildBlocking"] = nil
	end)

	it("declares DisableBuildOption and its parameters", function()
		assert.are.same({
			type = "DisableBuildOption",
			builtUnitDefID = "UnitDefID!",
			builderUnitDefID = "UnitDefID",
			teamID = "TeamID!",
		}, summarizeSchema(disableAction))
	end)

	it("declares EnableBuildOption with the same parameters", function()
		assert.are.same({
			type = "EnableBuildOption",
			builtUnitDefID = "UnitDefID!",
			builderUnitDefID = "UnitDefID",
			teamID = "TeamID!",
		}, summarizeSchema(enableAction))
	end)

	describe("DisableBuildOption", function()
		it("blocks the unit for every builder of the team under the mission reason", function()
			disableAction.actionFunction(42, nil, 1)

			assert.are.equal(1, #calls.add)
			assert.are.same({ unitDefID = 42, teamID = 1, reasonKey = "mission" }, calls.add[1])
			assert.are.equal(0, #calls.remove)
		end)

		it("limits the block to the given builder unit type", function()
			disableAction.actionFunction(42, 7, 1)

			assert.are.equal(1, #calls.add)
			assert.are.equal(7, calls.add[1].builderUnitDefID)
			assert.are.equal(42, calls.add[1].unitDefID)
			assert.are.equal(1, calls.add[1].teamID)
		end)
	end)

	describe("EnableBuildOption", function()
		it("lifts the mission block for every builder of the team", function()
			enableAction.actionFunction(42, nil, 1)

			assert.are.equal(1, #calls.remove)
			assert.are.same({ unitDefID = 42, teamID = 1, reasonKey = "mission" }, calls.remove[1])
			assert.are.equal(0, #calls.add)
		end)

		it("lifts the block for the given builder unit type only", function()
			enableAction.actionFunction(42, 7, 1)

			assert.are.equal(1, #calls.remove)
			assert.are.equal(7, calls.remove[1].builderUnitDefID)
		end)

		it("uses the same reason key as DisableBuildOption", function()
			disableAction.actionFunction(42, nil, 0)
			enableAction.actionFunction(42, nil, 0)

			assert.are.equal(calls.add[1].reasonKey, calls.remove[1].reasonKey)
		end)
	end)

end)
