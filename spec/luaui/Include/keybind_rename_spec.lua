local keybindModel = require("luaui/Include/keybind_model")

describe("changing the command a custom keybind runs", function()
	local binds = {
		{ keyset = "sc_q", action = "say gg" },
		{ keyset = "sc_q", action = "attack" },
		{ keyset = "Ctrl+sc_q", action = "say gg" },
	}

	-- Two actions on one keyset are tried in bind order, so moving the bind would change which fires.
	it("keeps each key where it sat among the others", function()
		assert.are.same({
			{ keyset = "sc_q", action = "say hello" },
			{ keyset = "sc_q", action = "attack" },
			{ keyset = "Ctrl+sc_q", action = "say hello" },
		}, keybindModel.renameAction(binds, "say gg", "say hello"))
	end)

	-- The engine refuses a second bind of one keyset to one action.
	it("drops a key the new command already has", function()
		assert.are.same({
			{ keyset = "sc_q", action = "attack" },
			{ keyset = "Ctrl+sc_q", action = "attack" },
		}, keybindModel.renameAction(binds, "say gg", "attack"))
	end)

	it("leaves the list it was given alone", function()
		keybindModel.renameAction(binds, "say gg", "say hello")

		assert.are.equal("say gg", binds[1].action)
	end)
end)
