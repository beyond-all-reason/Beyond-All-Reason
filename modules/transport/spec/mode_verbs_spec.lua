local ModuleHandler = require("modules/module_handler")
local TransportEnums = require("modules/transport/enums")

describe("transport's verbs on the game axis", function()
	before_each(function()
		ModuleHandler.ResetCaches()
	end)

	it("are shipped for the game axis and found by the loader", function()
		local verbs = ModuleHandler.ModeVerbs("game")
		assert.is_not_nil(verbs.SlowComTransport)
		assert.is_not_nil(verbs.EnemyTransporting)
	end)

	it("the Standard preset claims both options, or the lobby would never show them", function()
		local standard = require("modules/game/modes/standard")
		assert.are.same(
			{ value = false, locked = false },
			standard.modOptions[TransportEnums.ModOptions.CommanderTransportSlow]
		)
		assert.are.same(
			{ value = TransportEnums.TransportEnemy.NotCommanders, locked = false },
			standard.modOptions[TransportEnums.ModOptions.TransportEnemy]
		)
	end)

	it("check what the preset wrote", function()
		local Mode = require("modules/game/mode_dsl").Mode
		assert.has_error(function()
			Mode("Spec").SlowComTransport("yes")
		end, "Spec: .SlowComTransport expects true or false")
		assert.has_error(function()
			Mode("Spec").EnemyTransporting("everyone")
		end)
	end)
end)
