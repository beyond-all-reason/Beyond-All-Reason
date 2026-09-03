local ModuleHandler = VFS.Include("modules/module_handler.lua")
local TransportEnums = VFS.Include("modules/transport/enums.lua")

describe("transport's stage on the unit def fold", function()
	local pipeline = ModuleHandler.LoadPolicies("defs").unit_def ---@type AssembledPipeline<DefContext, DefContext>

	local function enemyTransport(which, def)
		-- run transport's stage alone: the base game's post wants a full def
		for _, stage in ipairs(pipeline) do
			if stage.name == "EnemyTransport" then
				stage.evaluate({
					name = "spec",
					def = def,
					modOptions = { [TransportEnums.ModOptions.TransportEnemy] = which },
				})
				return def
			end
		end
		error("no EnemyTransport stage")
	end

	it("follows the base game's post", function()
		local order = {}
		for i, stage in ipairs(pipeline) do
			order[stage.name] = i
		end
		assert.is_true(order.Base < order.EnemyTransport)
	end)

	it("makes commanders immune under All But Commanders, and everyone under Disallow All", function()
		local commander = { customparams = { iscommander = "1" } }
		local tank = { customparams = {} }
		assert.is_false(enemyTransport(TransportEnums.TransportEnemy.NotCommanders, commander).transportbyenemy)
		assert.is_nil(enemyTransport(TransportEnums.TransportEnemy.NotCommanders, tank).transportbyenemy)
		assert.is_false(enemyTransport(TransportEnums.TransportEnemy.None, tank).transportbyenemy)
	end)
end)
