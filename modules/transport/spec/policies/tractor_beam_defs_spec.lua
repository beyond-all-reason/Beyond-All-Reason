local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Contract = VFS.Include("modules/transport/contract.lua") ---@type TransportContract

describe("the tractor beam stage on the unit def fold", function()
	local pipeline = ModuleHandler.LoadPolicies("defs").unit_def ---@type AssembledPipeline<DefContext, DefContext>

	local function stage()
		for _, s in ipairs(pipeline) do
			if s.name == Contract.UnitDef.TractorBeams then
				return s
			end
		end
		error("no TractorBeams stage")
	end

	it("runs before the base game's post, as the block it replaces did", function()
		local order = {}
		for i, s in ipairs(pipeline) do
			order[s.name] = i
		end
		assert.is_true(order[Contract.UnitDef.TractorBeams] < order.Base)
	end)

	it("leaves a def alone while tractor beams are off", function()
		local def = { customparams = {}, buildoptions = {} }
		stage().evaluate({ name = "corvalk", def = def, modOptions = {} })
		stage().evaluate({ name = "corvalk", def = def, modOptions = { beta_tractorbeam = "disabled" } })
		assert.is_nil(def.objectname)
		assert.is_nil(def.script)
	end)

	it("rewrites a managed carrier under the vanilla ruleset", function()
		local ruleset = VFS.Include("modules/transport/tractor_beams/transporter_defs_vanilla.lua")
		local name = next(ruleset.transporters)
		local def = { customparams = {}, buildoptions = {} }
		stage().evaluate({ name = name, def = def, modOptions = { beta_tractorbeam = "vanilla" } })
		assert.are.equal("units/" .. name .. "_tractorbeam.s3o", def.objectname)
		assert.is_string(def.script)
		assert.is_truthy(def.script:find("^modules/transport/scripts/"))
	end)
end)
