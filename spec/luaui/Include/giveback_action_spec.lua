local SpecEnv = VFS.Include("spec/support/spec_env.lua")

describe("Give back in the player list", function()
	local function setup()
		local state = { remaining = 2, active = 1, allied = true, dead = false, ai = false }
		local commands = {}
		local env = SpecEnv.new({
			Spring = {
				AreTeamsAllied = function()
					return state.allied
				end,
				GetTeamInfo = function()
					return 2, 2, state.dead, state.ai
				end,
				GetTeamLuaAI = function()
					return ""
				end,
				GetTeamRulesParam = function(team, key)
					if team == 1 and key == "givebackUnits2" then
						return state.remaining
					end
					if team == 2 and key == "numActivePlayers" then
						return state.active
					end
				end,
				SendCommands = function(command)
					commands[#commands + 1] = command
				end,
			},
		})
		return SpecEnv.include(env, "luaui/Include/giveback_action.lua"), state, commands
	end

	it("offers giveback for a returning ally and sends the server command", function()
		local action, _, commands = setup()
		assert.is_true(action.available(1, 2, false))
		assert.is_true(action.run(1, 2, false))
		assert.same({ "luarules giveback 2" }, commands)
	end)

	it("hides the action before return, after giveback, and from spectators or enemies", function()
		local action, state, commands = setup()
		assert.is_false(action.available(1, 1, false))
		assert.is_false(action.run(1, 2, true))
		state.active = 0
		assert.is_false(action.run(1, 2, false))
		state.active, state.remaining = 2, 0
		assert.is_false(action.run(1, 2, false))
		state.remaining, state.allied = 2, false
		assert.is_false(action.run(1, 2, false))
		state.allied, state.dead = true, true
		assert.is_false(action.run(1, 2, false))
		state.dead, state.ai = false, true
		assert.is_false(action.run(1, 2, false))
		assert.same({}, commands)
	end)

	it("hides giveback as soon as the last taken unit disappears", function()
		local action, state, commands = setup()
		assert.is_true(action.available(1, 2, false))
		state.remaining = 1
		assert.is_true(action.available(1, 2, false))
		state.remaining = 0
		assert.is_false(action.available(1, 2, false))
		assert.is_false(action.run(1, 2, false))
		state.remaining = nil
		assert.is_false(action.available(1, 2, false))
		assert.same({}, commands)
	end)
end)
