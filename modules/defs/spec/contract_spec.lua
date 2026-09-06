local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Contract = VFS.Include("modules/defs/contract.lua") ---@type DefsContract

describe("defs pipelines", function()
	local pipelines = ModuleHandler.LoadPolicies(Modules.Defs) ---@type DefsPipelines

	it("are folds over one def, with the base game's post as a named stage", function()
		for _, category in ipairs({ "unit_def", "weapon_def" }) do
			local pipeline = pipelines[category]
			assert.are.equal("fold", pipeline.result, category)
			local named = {}
			for _, stage in ipairs(pipeline) do
				named[stage.name] = true
			end
			assert.is_true(named.Base, category)
		end
		assert.are.same(
			{ owner = "defs", category = "unit_def", result = "fold" },
			PolicyBuilder.IdentityOf(Contract.UnitDef)
		)
	end)

	-- The real fold, gamedata/alldefs_post.lua included, runs under
	-- spec/gamedata/unitdefs_spec.lua through the builder's WithRealUnitDefs.
end)
