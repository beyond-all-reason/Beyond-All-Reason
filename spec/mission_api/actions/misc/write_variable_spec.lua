GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
GG["MissionAPI"].Modules.Variables = VFS.Include("luarules/mission_api/variables.lua")

local actions = VFS.Include("luarules/mission_api/actions/misc/write_variable.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.write_variable", function()

	before_each(function()
		GG["MissionAPI"].Variables = { loaded = 1 }
		GG["MissionAPI"].PersistentVariableKeys = { loaded = true }
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "WriteVariable",
			key = "VariableKey!",
			value = "VariableValue!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("overwrites an existing value and keeps it persistent", function()
			action.actionFunction("loaded", 2)
			assert.are.equal(2, GG["MissionAPI"].Variables.loaded)
			assert.is_true(GG["MissionAPI"].PersistentVariableKeys.loaded)
		end)

		it("writes a copy of a table value", function()
			local value = { count = 1 }
			action.actionFunction("progress", value)
			GG["MissionAPI"].Variables.progress.count = 2
			assert.are.same({ count = 1 }, value)
		end)
	end)

end)
