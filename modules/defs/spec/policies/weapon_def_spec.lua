local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

describe("a weapon def, once the engine has read it", function()
	it("passes through the base game's post-processing, as one named step every module can stand beside", function()
		local Contract = ModuleHandler.Contract(Modules.Defs)
		local policy = ModuleHandler.Steps(Contract.WeaponDef)
		assert.are.equal("fold", policy.result)
		local named = {}
		for _, step in ipairs(policy) do
			named[step.name] = true
		end
		assert.is_true(named[Contract.WeaponDef.Base])
	end)
end)
