local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

-- the engine a build context carries; a step of another module may ask it (the assist tax reads the modoptions)
local springRepo = {
	GetModOptions = function()
		return {}
	end,
	GetTeamRulesParam = function()
		return nil
	end,
}

local function decide(policy, ctx)
	ctx.springRepo = springRepo
	return ModuleHandler.Evaluate(policy, ctx)
end

describe("one step of a builder's work", function()
	local Contract = ModuleHandler.Contract(Modules.Construction)

	it("a delayed builder builds nothing", function()
		assert.is_false(decide(Contract.Build, { builderID = 1, builderTeam = 0, delayed = true, part = 0.1 }))
		assert.is_true(decide(Contract.Build, { builderID = 1, builderTeam = 0, delayed = false, part = 0.1 }))
	end)
end)
