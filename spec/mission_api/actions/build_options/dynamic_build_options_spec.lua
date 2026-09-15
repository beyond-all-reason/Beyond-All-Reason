require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/build_options/dynamic_build_options.lua")
local summarizeSchema = require("mission_api.schema_spec_helper")

local function findAction(actionType)
	for _, action in ipairs(actions) do
		if action.type == actionType then
			return action
		end
	end
	error("no action of type " .. actionType)
end

local addAction = findAction("AddBuildOption")
local removeAction = findAction("RemoveBuildOption")

describe("mission_api.actions.dynamic_build_options", function()

	---@type { add: table[], remove: table[] }
	local calls

	before_each(function()
		calls = { add = {}, remove = {} }
		GG["DynamicBuildOptions"] = {
			Add = function(builtUnitDefID, builderUnitDefID, position)
				calls.add[#calls.add + 1] = {
					builtUnitDefID = builtUnitDefID,
					builderUnitDefID = builderUnitDefID,
					position = position,
				}
				return true
			end,
			Remove = function(builtUnitDefID, builderUnitDefID)
				calls.remove[#calls.remove + 1] = {
					builtUnitDefID = builtUnitDefID,
					builderUnitDefID = builderUnitDefID,
				}
				return true
			end,
		}
	end)

	after_each(function()
		GG["DynamicBuildOptions"] = nil
	end)

	it("declares AddBuildOption and its parameters", function()
		assert.are.same({
			type = "AddBuildOption",
			builtUnitDefID = "UnitDefID!",
			builderUnitDefID = "UnitDefID!",
			buildMenuPosition = "PositiveInteger",
		}, summarizeSchema(addAction))
	end)

	it("declares RemoveBuildOption and its parameters", function()
		assert.are.same({
			type = "RemoveBuildOption",
			builtUnitDefID = "UnitDefID!",
			builderUnitDefID = "UnitDefID!",
		}, summarizeSchema(removeAction))
	end)

	describe("AddBuildOption", function()
		it("adds the option to the builder type at the end of its build options", function()
			addAction.actionFunction(42, 7, nil)

			assert.are.equal(1, #calls.add)
			assert.are.same({ builtUnitDefID = 42, builderUnitDefID = 7 }, calls.add[1])
			assert.are.equal(0, #calls.remove)
		end)

		it("passes the build menu position through", function()
			addAction.actionFunction(42, 7, 3)

			assert.are.equal(1, #calls.add)
			assert.are.same({ builtUnitDefID = 42, builderUnitDefID = 7, position = 3 }, calls.add[1])
		end)
	end)

	describe("RemoveBuildOption", function()
		it("removes the option from the builder type", function()
			removeAction.actionFunction(42, 7)

			assert.are.equal(1, #calls.remove)
			assert.are.same({ builtUnitDefID = 42, builderUnitDefID = 7 }, calls.remove[1])
			assert.are.equal(0, #calls.add)
		end)
	end)

end)
