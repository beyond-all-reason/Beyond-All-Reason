local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Stages = VFS.Include("modules/transport/contract.lua").Load

local function decide(ctx)
	ModuleHandler.ResetCaches()
	local pipelines = ModuleHandler.LoadPolicies("transport") ---@type TransportPipelines
	return ModuleHandler.Evaluate(pipelines.load, ctx)
end

local function passenger(moveDefName)
	return { moveDef = { name = moveDefName } }
end

describe("a mod's rule on the transport module", function()
	it("joins the checks, ahead of the answer", function()
		local names = {}
		for i, stage in ipairs(ModuleHandler.LoadPolicies("transport").load) do
			names[i] = stage.name
		end
		assert.are.same({
			Stages.Submerged,
			Stages.WithinReach,
			Stages.MovingEnemy,
			Stages.AlliedNano,
			"TanksStayOnTheGround",
			Stages.Allowed,
		}, names)
	end)

	it("keeps tanks on the ground", function()
		assert.is_false(decide({ goalY = 10, height = 20, passengerDef = passenger("TANK3") }))
	end)

	it("lets bots ride, and everything the base game already allowed", function()
		assert.is_true(decide({ goalY = 10, height = 20, passengerDef = passenger("BOT3") }))
		assert.is_true(decide({ goalY = 10, height = 20, passengerDef = passenger("HOVER3") }))
		assert.is_true(decide({ goalY = 10, height = 20 }))
	end)

	it("does not touch what the base game refuses", function()
		assert.is_false(decide({ goalY = -30, height = 10, passengerDef = passenger("BOT3") }))
	end)
end)
