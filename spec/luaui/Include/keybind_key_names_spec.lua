-- Keys the engine has no scancode name for print as a number ("sc_0x039"), which tells a player
-- nothing about which key it is. These are the keys that matter on common keyboards.

local keybindModel = require("luaui/Include/keybind_model")

describe("keys the engine only numbers", function()
	it("reads the lock keys by name", function()
		assert.are.equal("CAPSLOCK", keybindModel.displayKeyset("sc_0x039", "qwerty"))
		assert.are.equal("SCROLLOCK", keybindModel.displayKeyset("sc_0x047", "qwerty"))
		assert.are.equal("NUMLOCK", keybindModel.displayKeyset("sc_0x053", "qwerty"))
	end)

	it("reads the ISO key by the legend most layouts print on it", function()
		assert.are.equal("CTRL + ISO <>", keybindModel.displayKeyset("Ctrl+sc_0x064", "qwertz"))
		assert.are.equal("CTRL + ISO <>", keybindModel.displayKeyset("Ctrl+sc_nonusbackslash", "qwertz"))
	end)

	-- The shipped profiles name it by number, and capturing the key names it, so a conflict
	-- between the two would otherwise go unnoticed.
	it("treats the ISO key by number and by name as one key", function()
		assert.are.equal(
			keybindModel.canonicalKeyset("Ctrl+sc_nonusbackslash"),
			keybindModel.canonicalKeyset("Ctrl+sc_0x064")
		)
	end)
end)
