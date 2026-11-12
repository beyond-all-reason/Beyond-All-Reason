local SpecEnv = VFS.Include("spec/support/spec_env.lua")
local summarizeSchema = require("mission_api.schema_spec_helper")

local ACTIONS_PATH = "luarules/mission_api/actions/misc/hints.lua"

-- The actions over a world of game rules params at game frame 300.
local function load()
	local params = {}
	local env = SpecEnv.new({
		Game = { gameSpeed = 30 },
		Spring = {
			SetGameRulesParam = function(name, value, access)
				assert.are.same({ public = true }, access)
				params[name] = value
			end,
			GetGameRulesParam = function(name)
				return params[name]
			end,
			GetGameFrame = function()
				return 300
			end,
		},
	})
	env.GG.MissionAPI = { Modules = { ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua") } }
	local actions = SpecEnv.include(env, ACTIONS_PATH)
	return actions[1], actions[2], params
end

describe("mission_api.actions.hints", function()
	it("declares its types and parameters", function()
		local showHint, hideHint = load()
		assert.are.same({
			type = "ShowHint",
			messageKey = "String!",
			messageData = "Table",
			seconds = "Number",
		}, summarizeSchema(showHint))
		assert.are.same({ type = "HideHint" }, summarizeSchema(hideHint))
	end)

	it("publishes a hint that stays until hidden, and bumps the serial", function()
		local showHint, _, params = load()
		showHint.actionFunction("tutorial.build_solar")
		assert.are.equal("tutorial.build_solar", params.mission_hint_key)
		assert.is_nil(params.mission_hint_data)
		assert.are.equal(0, params.mission_hint_until)
		assert.are.equal(1, params.mission_hint_serial)
	end)

	it("ends a timed hint at the game frame its seconds run out, and carries its data", function()
		local showHint, _, params = load()
		showHint.actionFunction("tutorial.mex", { count = 2 }, 2.5)
		assert.are.equal(300 + 75, params.mission_hint_until)
		assert.are.same({ count = 2 }, Json.decode(params.mission_hint_data))
	end)

	it("clears the hint on HideHint", function()
		local showHint, hideHint, params = load()
		showHint.actionFunction("tutorial.build_solar")
		hideHint.actionFunction()
		assert.is_nil(params.mission_hint_key)
		assert.are.equal(2, params.mission_hint_serial)
	end)
end)
