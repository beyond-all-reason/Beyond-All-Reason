local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")
local TechEnums = require("modules/tech/enums")

describe("what tech blocking does to a unit def", function()
	local Contract = ModuleHandler.Contract(Modules.Tech)
	local policy = ModuleHandler.Steps(ModuleHandler.Contract(Modules.Defs).UnitDef)

	local function post(name, def, techBlocking)
		for _, step in ipairs(policy) do
			if step.name == Contract.UnitDef.TechBlocking then
				step.evaluate({
					name = name,
					def = def,
					modOptions = { [TechEnums.ModOptions.TechBlocking] = techBlocking },
				})
				return def
			end
		end
		error("no TechBlocking step")
	end

	local function con(opts)
		return { speed = 1.5, buildoptions = opts, customparams = { techlevel = "1" } }
	end

	it("is a step after the base game's post", function()
		local order = {}
		for i, step in ipairs(policy) do
			order[step.name] = i
		end
		assert.is_true(order.Base < order[Contract.UnitDef.TechBlocking])
	end)

	it("puts the faction's Keystone in the menu of a T1 constructor that builds the mex", function()
		assert.same({ "armmex", "armkeystone" }, post("armck", con({ "armmex" }), true).buildoptions)
		assert.same({ "cormex", "corkeystone" }, post("corck", con({ "cormex" }), true).buildoptions)
		assert.same({ "legmex", "legkeystone" }, post("legck", con({ "legmex" }), true).buildoptions)
	end)

	it("leaves specialised builders, commanders, T2 constructors and buildings alone", function()
		assert.same({ "armnanotc" }, post("armrectr", con({ "armnanotc" }), true).buildoptions)
		local commander = con({ "armmex" })
		commander.customparams.iscommander = "1"
		assert.same({ "armmex" }, post("armcom", commander, true).buildoptions)
		local t2 = con({ "armmex" })
		t2.customparams.techlevel = "2"
		assert.same({ "armmex" }, post("armack", t2, true).buildoptions)
		local building = { speed = 0, buildoptions = { "armmex" }, customparams = {} }
		assert.same({ "armmex" }, post("armnanotc", building, true).buildoptions)
	end)

	it("the Voussoir builds it though it builds no mex, and a menu that has it gets it once", function()
		assert.same({ "armspringer", "armkeystone" }, post("armvoussoir", con({ "armspringer" }), true).buildoptions)
		assert.same({ "armmex", "armkeystone" }, post("armck", con({ "armmex", "armkeystone" }), true).buildoptions)
	end)

	it("makes the T2 labs cheaper and blocks Legion's T1.5 mex", function()
		local lab = post("armalab", { metalcost = 2900, customparams = {} }, true)
		assert.equal(1700, lab.metalcost)
		assert.equal(10000, lab.energycost)
		assert.is_true(post("legmext15", { customparams = {} }, true).customparams.modoption_blocked)
	end)

	it("does nothing when the option is off", function()
		assert.same({ "armmex" }, post("armck", con({ "armmex" }), false).buildoptions)
		assert.equal(2900, post("armalab", { metalcost = 2900, customparams = {} }, false).metalcost)
	end)
end)
