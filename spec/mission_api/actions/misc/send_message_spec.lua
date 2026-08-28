require("spec_helper")

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local summarizeSchema = require("mission_api.schema_spec_helper")

local sentMessages = {}
local realEcho = Spring.Echo
Spring.Echo = function(message)
	sentMessages[#sentMessages + 1] = message
end
local action = VFS.Include("luarules/mission_api/actions/misc/send_message.lua")[1]
Spring.Echo = realEcho

describe("mission_api.actions.send_message", function()
	before_each(function()
		sentMessages = {}
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "SendMessage",
			message = "String!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("sends the message it is given", function()
			action.actionFunction("hello mission")

			assert.are.same({ "hello mission" }, sentMessages)
		end)
	end)
end)
