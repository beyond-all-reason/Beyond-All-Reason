local redirectTakeCommand = require("luaui/Include/take_command")

describe("Take command redirection", function()
	it("routes giveback commands with their target and modifiers", function()
		assert.equal("luarules giveback 2", redirectTakeCommand("giveback 2", true))
		assert.equal("@@luarules giveback 2", redirectTakeCommand("@@GiveBack 2", true))
		assert.equal("giveback 2", redirectTakeCommand("giveback 2", false))
		assert.equal("givebackall", redirectTakeCommand("givebackall", true))
	end)
	it("routes the native action to the multiplayer take manager", function()
		assert.equal("luarules take2", redirectTakeCommand("take", true))
		assert.equal("luarules take2 ", redirectTakeCommand("take ", true))
		assert.equal("  luarules take2  ", redirectTakeCommand("  TaKe  ", true))
		assert.equal("luarules take2 3", redirectTakeCommand("take 3", true))
	end)

	it("preserves the engine's command modifiers", function()
		assert.equal("@@luarules take2", redirectTakeCommand("@@take", true))
		assert.equal("@!s@luarules take2 3", redirectTakeCommand("@!s@take 3", true))
	end)

	it("leaves the native action available in singleplayer", function()
		assert.equal("take", redirectTakeCommand("take", false))
		assert.equal("@@take", redirectTakeCommand("@@take", false))
	end)

	it("only rewrites the exact action, not chat or other commands", function()
		for _, command in ipairs({ "say take", "luarules take2 3", "take2", "takeover", "bind t take", "", "@take" }) do
			assert.equal(command, redirectTakeCommand(command, true))
		end
		assert.equal(1, redirectTakeCommand(1, true))
	end)
end)
