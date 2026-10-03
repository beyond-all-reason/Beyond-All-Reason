local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")
local TransportEnums = require("modules/transport/enums")

describe("whether an enemy may carry a unit", function()
	local Contract = ModuleHandler.Contract(Modules.Transport)
	local policy = ModuleHandler.Steps(ModuleHandler.Contract(Modules.Defs).UnitDef)

	local function enemyTransport(which, def)
		for _, step in ipairs(policy) do
			if step.name == Contract.UnitDef.EnemyTransport then
				step.evaluate({
					name = "spec",
					def = def,
					modOptions = { [TransportEnums.ModOptions.TransportEnemy] = which },
				})
				return def
			end
		end
		error("no EnemyTransport step")
	end

	it("is written onto its def after the base game's post", function()
		local order = {}
		for i, step in ipairs(policy) do
			order[step.name] = i
		end
		assert.is_true(order.Base < order[Contract.UnitDef.EnemyTransport])
	end)

	it("makes commanders immune under All But Commanders, and everyone under Disallow All", function()
		local commander = { customparams = { iscommander = "1" } }
		local tank = { customparams = {} }
		assert.is_false(enemyTransport(TransportEnums.TransportEnemy.NotCommanders, commander).transportbyenemy)
		assert.is_nil(enemyTransport(TransportEnums.TransportEnemy.NotCommanders, tank).transportbyenemy)
		assert.is_false(enemyTransport(TransportEnums.TransportEnemy.None, tank).transportbyenemy)
	end)
end)
