local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/build_options/build_option_blocking.lua")
local summarizeSchema = require("mission_api.schema_spec_helper")

local unitDefNames =
	Builders.UnitDefs.new():WithUnitDefs({ [42] = { name = "armsolar" }, [7] = { name = "armck" } }):GetUnitDefNames()

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

	---@type { add: table[], remove: table[] }
	local calls

	before_each(function()
		calls = { add = {}, remove = {} }
		_G.UnitDefNames = unitDefNames ---@diagnostic disable-line: global-in-non-module
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
			builtDefName = "UnitDefName!",
			builderDefName = "UnitDefName",
			teamID = "TeamID!",
			hidden = "Boolean",
		}, summarizeSchema(disableAction))
	end)

	it("declares EnableBuildOption with the same parameters, without hidden", function()
		assert.are.same({
			type = "EnableBuildOption",
			builtDefName = "UnitDefName!",
			builderDefName = "UnitDefName",
			teamID = "TeamID!",
		}, summarizeSchema(enableAction))
	end)

	describe("DisableBuildOption", function()
		it("blocks the unit for every builder of the team under the mission reason", function()
			disableAction.actionFunction("armsolar", nil, 1)

			assert.are.equal(1, #calls.add)
			assert.are.same({ unitDefID = 42, teamID = 1, reasonKey = "mission" }, calls.add[1])
			assert.are.equal(0, #calls.remove)
		end)

		it("limits the block to the given builder unit type", function()
			disableAction.actionFunction("armsolar", "armck", 1)

			assert.are.equal(1, #calls.add)
			assert.are.same({ unitDefID = 42, teamID = 1, reasonKey = "mission", builderUnitDefID = 7 }, calls.add[1])
		end)

		it("also blocks under the hidden reason when hidden, which takes the unit out of the build menu", function()
			disableAction.actionFunction("armsolar", nil, 1, true)

			assert.are.same({
				{ unitDefID = 42, teamID = 1, reasonKey = "mission" },
				{ unitDefID = 42, teamID = 1, reasonKey = "hidden" },
			}, calls.add)
		end)

		it("ignores hidden for one builder unit type, as the build menu hides team-wide blocks only", function()
			disableAction.actionFunction("armsolar", "armck", 1, true)

			assert.are.same({
				{ unitDefID = 42, teamID = 1, reasonKey = "mission", builderUnitDefID = 7 },
			}, calls.add)
		end)
	end)

	describe("EnableBuildOption", function()
		it("lifts the mission and hidden blocks for every builder of the team", function()
			enableAction.actionFunction("armsolar", nil, 1)

			assert.are.same({
				{ unitDefID = 42, teamID = 1, reasonKey = "mission" },
				{ unitDefID = 42, teamID = 1, reasonKey = "hidden" },
			}, calls.remove)
			assert.are.equal(0, #calls.add)
		end)

		it("lifts the block for the given builder unit type only", function()
			enableAction.actionFunction("armsolar", "armck", 1)

			assert.are.equal(1, #calls.remove)
			assert.are.same(
				{ unitDefID = 42, teamID = 1, reasonKey = "mission", builderUnitDefID = 7 },
				calls.remove[1]
			)
		end)

		it("removes exactly what DisableBuildOption added", function()
			disableAction.actionFunction("armsolar", nil, 0)
			enableAction.actionFunction("armsolar", nil, 0)

			assert.are.same(calls.add[1], calls.remove[1])
		end)

		it("lifts both reasons after a hidden DisableBuildOption", function()
			disableAction.actionFunction("armsolar", nil, 1, true)
			enableAction.actionFunction("armsolar", nil, 1)

			assert.are.same({
				{ unitDefID = 42, teamID = 1, reasonKey = "mission" },
				{ unitDefID = 42, teamID = 1, reasonKey = "hidden" },
			}, calls.remove)
		end)

		it("keeps the team-wide hidden reason when lifting the block for one builder unit type", function()
			disableAction.actionFunction("armsolar", nil, 1, true)
			enableAction.actionFunction("armsolar", "armck", 1)

			assert.are.same(
				{ { unitDefID = 42, teamID = 1, reasonKey = "mission", builderUnitDefID = 7 } },
				calls.remove
			)
		end)
	end)

end)
