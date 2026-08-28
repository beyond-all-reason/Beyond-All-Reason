require("spec_helper")

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

-- The action captures the module at load, as every action does for ParameterTypes, so
-- it has to exist before the include. Tests reset its record rather than replace it.
local sent = {}
GG["MissionAPI"].Modules.Presentation = {
	SendMessage = function(message, audience)
		sent[#sent + 1] = { message = message, audience = audience }
	end,
}

local actions = VFS.Include("luarules/mission_api/actions/misc/send_message.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.send_message", function()

	it("declares its type and parameters", function()
		assert.are.same({
			type = "SendMessage",
			message = "String!",
			audience = "Table",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		before_each(function()
			for i = #sent, 1, -1 do
				sent[i] = nil
			end
		end)

		it("delegates to the presentation module", function()
			action.actionFunction("hello mission")
			assert.are.equal(1, #sent)
			assert.are.equal("hello mission", sent[1].message)
		end)

		it("passes the audience through", function()
			action.actionFunction("hello mission", { playerIDs = { 3 } })
			assert.are.same({ playerIDs = { 3 } }, sent[1].audience)
		end)
	end)

end)
