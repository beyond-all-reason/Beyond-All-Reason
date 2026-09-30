-- The builder reads these at load or on first use; the game provides them, the specs do not.
rawset(_G, "utf8", rawget(_G, "utf8") or { len = string.len, sub = string.sub })
Spring.GetTimer = Spring.GetTimer or function() end
Spring.DiffTimers = Spring.DiffTimers or function()
	return 0
end
math.isInRect = math.isInRect
	or function(x, y, x1, y1, x2, y2)
		return x >= x1 and x <= x2 and y >= y1 and y <= y2
	end
_G.WG = _G.WG
	or {
		fonts = {
			getFont = function()
				return {
					GetTextWidth = function(_, s)
						return #s * 0.5
					end,
				}
			end,
		},
	}
_G.BAR = _G.BAR or {}
BAR.I18N = BAR.I18N or function(key)
	return key
end

local Builder = require("luaui/Include/keybind_select_builder")
local Json = require("common/luaUtilities/json")
local Select = require("luaui/Include/keybind_select")

local function shippedSelectActions()
	local file = assert(io.open("common/configs/keybind_catalog.json", "r"))
	local catalog = Json.decode(file:read("*a"))
	file:close()

	local actions = {}
	for _, category in ipairs(catalog) do
		for _, item in ipairs(category.items or {}) do
			local action = type(item) == "table" and item.action
			if action and action:find("^select ") then
				actions[#actions + 1] = action
			end
		end
	end

	return actions
end

local function echo(key, values)
	local parts = { (key:gsub("^ui%.keybinds%.select%.", "")) }
	for _, name in ipairs({ "conclusion", "filters", "source", "summary", "filter", "units", "last", "value" }) do
		if values and values[name] then
			parts[#parts + 1] = name .. "=" .. values[name]
		end
	end

	return "[" .. table.concat(parts, " ") .. "]"
end

describe("reading a select command", function()
	-- The catalog's own spellings are the ones players copy, so they have to survive the trip.
	it("writes every shipped selection back exactly as it reads it", function()
		local actions = shippedSelectActions()
		assert.is_true(#actions > 0)
		for _, action in ipairs(actions) do
			local spec = Select.parse(action)
			assert(spec, action)
			assert.are.equal(action, Select.format(spec))
		end
	end)

	it("takes a filter's values and its Not", function()
		local spec =
			assert(Select.parse("select PrevSelection+_Not_Building_Not_RelativeHealth_60+_ClearSelection_SelectAll+"))

		assert.are.same({
			{ id = "Building", negate = true, args = {} },
			{ id = "RelativeHealth", negate = true, args = { "60" } },
		}, spec.filters)
		assert.is_true(spec.clear)
		assert.are.equal("SelectAll", spec.conclusion)
	end)

	it("takes a source and a conclusion that carry a value", function()
		local spec = assert(Select.parse("select FromMouse_500+_Idle+_SelectNum_3+"))

		assert.are.equal("FromMouse", spec.source)
		assert.are.equal("500", spec.sourceArg)
		assert.is_false(spec.clear)
		assert.are.equal("SelectNum", spec.conclusion)
		assert.are.equal("3", spec.conclusionArg)
	end)

	it("leaves the filters that match nothing in BAR to be written by hand", function()
		for _, filter in ipairs({ "NameContain_Pawn", "Category_VTOL", "RulesParamEquals_role_scout" }) do
			assert.is_nil(Select.parse("select AllMap+_" .. filter .. "+_SelectAll+"))
		end
	end)

	-- The engine matches keywords as written, so a player's lower case spelling selects nothing.
	it("does not read a keyword the engine would not know", function()
		assert.is_nil(Select.parse("select AllMap+_builder+_SelectAll+"))
	end)

	it("does not read an unknown source or a missing conclusion", function()
		assert.is_nil(Select.parse("select Everywhere++_SelectAll+"))
		assert.is_nil(Select.parse("select AllMap++_ClearSelection+"))
	end)

	it("reads nothing from a command that is not a selection", function()
		assert.is_nil(Select.parse("attack"))
		assert.is_nil(Select.parse("select"))
	end)
end)

describe("checking a value typed for a selection", function()
	it("refuses what would end the token early", function()
		assert.is_false(Select.validArg("my_unit", "text"))
		assert.is_false(Select.validArg("a+b", "text"))
		assert.is_false(Select.validArg("two words", "text"))
		assert.is_true(Select.validArg("armcom", "text"))
	end)

	it("wants a number where the engine reads one", function()
		assert.is_false(Select.validArg("half", "number"))
		assert.is_true(Select.validArg("60", "number"))
	end)

	-- The engine reads a count or a control group with atoi, dropping whatever follows the digits.
	it("wants a whole number where the engine reads one", function()
		assert.is_false(Select.validArg("2.5", "whole"))
		assert.is_false(Select.validArg("-1", "whole"))
		assert.is_true(Select.validArg("3", "whole"))
	end)
end)

describe("putting a selection into words", function()
	it("names the conclusion, the filters and the source", function()
		local spec = Select.parse("select AllMap+_Builder_Not_Idle+_ClearSelection_SelectOne+")

		assert.are.equal(
			"[summary conclusion=[conclusion.SelectOne] filters=[filter.Builder], [not filter=[filter.Idle]] source=[source.AllMap]]",
			Select.describe(spec, echo)
		)
	end)

	it("leaves the filters out when there are none", function()
		local spec = Select.parse("select Visible++_ClearSelection_SelectAll+")

		assert.are.equal(
			"[summaryAll conclusion=[conclusion.SelectAll] source=[source.Visible]]",
			Select.describe(spec, echo)
		)
	end)

	it("says so when the selection is added to rather than replaced", function()
		local spec = Select.parse("select Visible++_SelectPart_50+")

		assert.are.equal(
			"[keepSelection summary=[summaryAll conclusion=[conclusion.SelectPart value=50] source=[source.Visible]]]",
			Select.describe(spec, echo)
		)
	end)
end)

describe("putting several unit names into words", function()
	it("joins plain unit names as a choice where the first of them stood", function()
		local spec = Select.parse("select AllMap+_Idle_IdMatches_armcom_IdMatches_corcom+_ClearSelection_SelectAll+")

		assert.are.equal(
			"[summary conclusion=[conclusion.SelectAll] filters=[filter.Idle], [anyOf units=[filter.IdMatches value=armcom] last=[filter.IdMatches value=corcom]] source=[source.AllMap]]",
			Select.describe(spec, echo)
		)
	end)

	it("leaves ruled-out names as filters of their own", function()
		local spec = Select.parse("select AllMap+_Not_IdMatches_armcom_Not_IdMatches_corcom+_ClearSelection_SelectAll+")

		assert.are.equal(
			"[summary conclusion=[conclusion.SelectAll] filters=[not filter=[filter.IdMatches value=armcom]], [not filter=[filter.IdMatches value=corcom]] source=[source.AllMap]]",
			Select.describe(spec, echo)
		)
	end)
end)

describe("what the builder can edit", function()
	it("takes a value filter once each way", function()
		assert.is_true(
			Select.editable(Select.parse("select AllMap+_WeaponRange_31999_Not_WeaponRange_33001+_SelectAll+"))
		)
	end)

	it("takes units named alongside units ruled out by name", function()
		assert.is_true(
			Select.editable(
				Select.parse("select AllMap+_IdMatches_armcom_Not_IdMatches_corcom_Not_IdMatches_legcom+_SelectAll+")
			)
		)
	end)

	it("refuses a value filter named twice the same way", function()
		assert.is_false(Select.editable(Select.parse("select AllMap+_RelativeHealth_30_RelativeHealth_70+_SelectAll+")))
	end)

	it("refuses a filter without a value named both ways", function()
		assert.is_false(Select.editable(Select.parse("select AllMap+_Weapons_Not_Weapons+_SelectAll+")))
	end)
end)

describe("telling whether an edit changed a selection", function()
	it("reads filters in another order as the same selection", function()
		assert.is_true(
			Select.sameSelection(
				"select AllMap+_Idle_Builder+_ClearSelection_SelectOne+",
				"select AllMap+_Builder_Idle+_ClearSelection_SelectOne+"
			)
		)
	end)

	it("reads a missing final + as the same selection", function()
		assert.is_true(
			Select.sameSelection("select Visible+_InGroup_1+_SelectAll", "select Visible+_InGroup_1+_SelectAll+")
		)
	end)

	it("tells a changed value apart", function()
		assert.is_false(
			Select.sameSelection(
				"select AllMap+_RelativeHealth_30+_SelectAll+",
				"select AllMap+_RelativeHealth_40+_SelectAll+"
			)
		)
	end)
end)

describe("the selection builder", function()
	local function open(action)
		local builder = Builder.new()
		builder:setArea(0, 0, 1100, 594, 1)
		builder:show(action and Select.parse(action), { title = "", acceptLabel = "", cancelLabel = "" })

		return builder
	end

	-- The engine ends a token at an underscore, so a scavenger or raptor name would split in two.
	it("refuses a unit name the engine would split", function()
		local builder = open(nil)
		builder.on.IdMatches = { is = true }
		local field = builder:argFields("IdMatches", "is")[1]

		field:setText("armcom_scav")
		assert.is_false(select(2, builder:spec()))

		field:setText("armcom")
		assert.is_true(select(2, builder:spec()))
	end)

	it("checks a source's or a conclusion's value as the kind it is", function()
		local builder = open("select FromMouse_150.5+_Idle+_ClearSelection_SelectNum_2.5+")
		assert.is_false(select(2, builder:spec()))

		builder.conclusionArg:setText("2")
		assert.is_true(select(2, builder:spec()))
	end)

	-- The game window can change size under an open form.
	it("moves with the area it is given while open", function()
		local builder = open(nil)
		builder:setArea(400, 300, 1500, 894, 1)
		local x1, y1, x2, y2 = builder:rect()

		assert.are.same({ 950, 597 }, { (x1 + x2) / 2, (y1 + y2) / 2 })
	end)

	it("saves a selection opened and left alone as that same selection", function()
		for _, action in ipairs({
			"select AllMap+_Idle_Builder+_ClearSelection_SelectOne+",
			"select Visible+_Weapons_Not_Aircraft+_ClearSelection_SelectAll+",
			"select FromMouseC_800+_Idle+_SelectNum_3+",
			"select PrevSelection++_SelectPart_50+",
			"select PrevSelection+_Not_Building_Not_RelativeHealth_60+_ClearSelection_SelectAll+",
			"select AllMap+_Building_WeaponRange_31999_Not_WeaponRange_33001+_ClearSelection_SelectAll+",
			"select AllMap+_Aircraft_Weapons_WeaponRange_1260_Not_WeaponRange_1300+_ClearSelection_SelectAll+",
			"select AllMap+_Building_WeaponRange_2100_Not_IdMatches_legabm_Not_IdMatches_armmercury+_ClearSelection_SelectAll+",
			"select AllMap+_Builder_Not_Building_IdMatches_corfast_IdMatches_armconsul+_ClearSelection_SelectClosestToCursor+",
			"select AllMap+_IdMatches_armcom_Not_IdMatches_corcom+_ClearSelection_SelectAll+",
			"select Visible+_InGroup_1_Not_Guarding+_ClearSelection_SelectAll",
		}) do
			assert.is_true(Select.editable(Select.parse(action)), action)
			assert.is_true(Select.sameSelection(action, Select.format((open(action):spec()))), action)
		end
	end)

	it("turns both ways of a value filter on and off on their own", function()
		local builder = open(nil)
		local g = assert(builder.g)
		local row = 0
		for i, id in ipairs(builder.order) do
			if id == "WeaponRange" then
				row = i
			end
		end
		builder.scroll = row - 1
		local y = g.listY2 - g.rowH * 0.5
		local function press(k)
			builder:mousePress(g.segX + (k - 0.5) * g.segW, y)
		end

		press(2)
		press(3)
		assert.are.same({ is = true, ["not"] = true }, builder.on.WeaponRange)
		press(2)
		assert.are.same({ ["not"] = true }, builder.on.WeaponRange)
		press(1)
		assert.are.same({}, builder.on.WeaponRange)
	end)

	it("closes an open list on Escape before the form itself", function()
		local builder = open(nil)
		builder.conclusionPicker.open = true

		builder:keyPress(27)
		assert.is_true(builder:isOpen())
		assert.is_false(builder.conclusionPicker:isOpen())

		builder:keyPress(27)
		assert.is_false(builder:isOpen())
	end)

	it("lets go of a field once its row scrolls out of view", function()
		local builder = open(nil)
		local g = assert(builder.g)
		builder.on.WeaponRange = { is = true }
		local field = builder:argFields("WeaponRange", "is")[1]
		builder.scroll = #builder.order
		builder:clampScroll()
		builder:focus(field)

		local realMouse = Spring.GetMouseState
		rawset(Spring, "GetMouseState", function()
			return g.x1 + 1, g.listY1 + 1
		end)
		for _ = 1, #builder.order do
			builder:mouseWheel(true)
		end
		rawset(Spring, "GetMouseState", realMouse)

		assert.is_false(field:isFocused())
		assert.is_false(builder:textInput("9"))
	end)
end)
