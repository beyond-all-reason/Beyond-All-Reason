local MissionSpecEnv = require("mission_api.spec_helper")
local summarizeSchema = require("mission_api.schema_spec_helper")

local env = MissionSpecEnv.new({ Game = { gameSpeed = 30 } })
MissionSpecEnv.registerModules(env)
local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/misc/hints.lua")
local showHint, hideHint = actions[1], actions[2]

describe("mission_api.actions.hints", function()
	local rulesParams, syncActions

	local function published()
		return rulesParams.missionHint and Json.decode(rulesParams.missionHint)
	end

	before_each(function()
		rulesParams, syncActions = {}, {}
		env.Spring.SetGameRulesParam = function(name, value)
			rulesParams[name] = value
		end
		env.Spring.GetGameFrame = function()
			return 300
		end
		env.SendToUnsynced = function(action)
			syncActions[#syncActions + 1] = action
		end
	end)

	it("declares its types and parameters", function()
		assert.are.same(
			{ type = "ShowHint", messageKey = "String!", messageData = "Table", seconds = "Quantity" },
			summarizeSchema(showHint)
		)
		assert.are.same({ type = "HideHint" }, summarizeSchema(hideHint))
	end)

	it("publishes a hint that stays until hidden, and tells LuaUI", function()
		showHint.actionFunction("tutorial.build_solar")
		assert.are.same({ messageKey = "tutorial.build_solar" }, published())
		assert.are.same({ "MissionHintChanged" }, syncActions)
	end)

	it("ends a timed hint when its seconds run out, at least one frame on", function()
		showHint.actionFunction("tutorial.mex", { count = 2 }, 2.5)
		assert.are.same({ messageKey = "tutorial.mex", messageData = { count = 2 }, untilFrame = 375 }, published())
		showHint.actionFunction("tutorial.flash", nil, 0)
		assert.are.equal(301, published().untilFrame)
	end)

	it("clears the hint on HideHint", function()
		showHint.actionFunction("tutorial.build_solar")
		hideHint.actionFunction()
		assert.is_nil(rulesParams.missionHint)
		assert.are.same({ "MissionHintChanged", "MissionHintChanged" }, syncActions)
	end)
end)
