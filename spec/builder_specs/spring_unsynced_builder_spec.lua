local Builders = VFS.Include("spec/builders/index.lua")

local WIDGET_PATH = "spec/fixtures/unsynced_widget.lua"

describe("SpringUnsyncedBuilder", function()

	it("loads a widget into a sandboxed env and runs Initialize", function()
		local widget = Builders.SpringUnsynced.new():LoadWidget(WIDGET_PATH)
		assert.is_table(widget.WG.tmp_unsynced)
	end)

	it("defaults to headless (Platform.gl is falsy)", function()
		local widget = Builders.SpringUnsynced.new():LoadWidget(WIDGET_PATH)
		assert.is_false(widget.WG.tmp_unsynced.seen.platformGl)
	end)

	it("exposes UnitDefs registered via WithUnitDef", function()
		local widget =
			Builders.SpringUnsynced.new():WithUnitDef(7, { name = "armcom", buildSpeed = 100 }):LoadWidget(WIDGET_PATH)

		local seenDefs = widget.WG.tmp_unsynced.seen.unitDefs
		assert.equals("armcom", seenDefs[7].name)
	end)

	it("maps unit IDs to def IDs by numeric defID", function()
		local widget = Builders.SpringUnsynced
			.new()
			:WithUnitDef(7, { name = "armcom", buildSpeed = 100 })
			:WithUnit(42, 7)
			:LoadWidget(WIDGET_PATH)

		assert.equals(7, widget.WG.tmp_unsynced.getUnitDefID(42))
		assert.is_nil(widget.WG.tmp_unsynced.getUnitDefID(99))
	end)

	it("WithUnit by unknown numeric defID errors", function()
		assert.has_error(function()
			Builders.SpringUnsynced.new():WithUnit(1, 999)
		end)
	end)

	it("resolves WithUnit by name when the def has been registered", function()
		local widget = Builders.SpringUnsynced
			.new()
			:WithUnitDef(7, { name = "armcom", buildSpeed = 100 })
			:WithUnit(42, "armcom")
			:LoadWidget(WIDGET_PATH)

		assert.equals(7, widget.WG.tmp_unsynced.getUnitDefID(42))
	end)

	it("WithUnit by unknown name errors with a helpful message", function()
		assert.has_error(function()
			Builders.SpringUnsynced.new():WithUnit(1, "nonesuch")
		end)
	end)

	it("WithUnitDef accepts a UnitDefBuilder", function()
		local widget = Builders.SpringUnsynced
			.new()
			:WithUnitDef(Builders.UnitDef.new("armcon"):WithDefID(100):WithSpeed(100):Builds(10, 11))
			:LoadWidget(WIDGET_PATH)

		local defs = widget.WG.tmp_unsynced.seen.unitDefs
		assert.equals("armcon", defs[100].name)
		assert.equals(100, defs[100].buildSpeed)
		assert.same({ 10, 11 }, defs[100].buildOptions)
	end)

	it("captureUnitOrders records GiveOrderToUnit calls", function()
		local widget = Builders.SpringUnsynced.new():LoadWidget(WIDGET_PATH)
		local calls = widget.captureUnitOrders()

		widget.WG.tmp_unsynced.callGiveOrder(5, -10)
		widget.WG.tmp_unsynced.callGiveOrder(6, -11)

		assert.equals(2, #calls)
		assert.same({ unitID = 5, cmdID = -10, params = {} }, calls[1])
		assert.same({ unitID = 6, cmdID = -11, params = {} }, calls[2])
	end)

	it("captureArrayOrders records GiveOrderArrayToUnitArray calls", function()
		local widget = Builders.SpringUnsynced.new():LoadWidget(WIDGET_PATH)
		local calls = widget.captureArrayOrders()

		widget.WG.tmp_unsynced.callGiveOrderArray({ 1, 2 }, { { -10 }, { -11 } })

		assert.equals(1, #calls)
		assert.same({ 1, 2 }, calls[1].unitIDs)
		assert.same({ { -10 }, { -11 } }, calls[1].orders)
	end)

	it("WithSpringFn overrides individual Spring functions", function()
		local widget = Builders.SpringUnsynced
			.new()
			:WithSpringFn("GetMyTeamID", function()
				return 99
			end)
			:LoadWidget(WIDGET_PATH)

		assert.equals(99, widget.env.Spring.GetMyTeamID())
	end)

	it("WithVFSInclude overrides VFS.Include for a specific path", function()
		local widget = Builders.SpringUnsynced
			.new()
			:WithVFSInclude("any/fake/path.lua", { sentinel = true })
			:LoadWidget(WIDGET_PATH)

		local result = widget.env.VFS.Include("any/fake/path.lua")
		assert.is_true(result.sentinel)
	end)

	it("each LoadWidget call yields an isolated env", function()
		local a = Builders.SpringUnsynced.new():LoadWidget(WIDGET_PATH)
		local b = Builders.SpringUnsynced.new():LoadWidget(WIDGET_PATH)
		assert.are_not.equal(a.env, b.env)
		assert.are_not.equal(a.WG, b.WG)
	end)
end)
