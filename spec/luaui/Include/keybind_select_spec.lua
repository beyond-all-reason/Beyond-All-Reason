local SpecEnv = VFS.Include("spec/support/spec_env.lua")

-- The builder reads these at load or on first use; the game provides them, the specs do not.
local env = SpecEnv.new({
	Spring = {
		GetTimer = function() end,
		DiffTimers = function()
			return 0
		end,
	},
	math = {
		isInRect = function(x, y, x1, y1, x2, y2)
			return x >= x1 and x <= x2 and y >= y1 and y <= y2
		end,
	},
	WG = {
		fonts = {
			getFont = function()
				return {
					GetTextWidth = function(_, s)
						return #s * 0.5
					end,
				}
			end,
		},
	},
	BAR = {
		I18N = function(key)
			return key
		end,
	},
})

local Builder = SpecEnv.include(env, "luaui/Include/keybind_select_builder.lua")
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
			local command = Select.parse(action)
			assert(command, action)
			assert.are.equal(action, Select.format(command))
		end
	end)

	it("takes each part and the values it carries", function()
		assert.are.same({
			source = "FromMouse",
			sourceArg = "500",
			filters = {
				{ id = "Building", negate = true, args = {} },
				{ id = "RelativeHealth", negate = false, args = { "60" } },
			},
			clear = true,
			conclusion = "SelectNum",
			conclusionArg = "3",
		}, Select.parse("select FromMouse_500+_Not_Building_RelativeHealth_60+_ClearSelection_SelectNum_3+"))
	end)

	it("reads nothing the builder could not hold", function()
		for _, action in ipairs({
			"select AllMap+_NameContain_Pawn+_SelectAll+",
			"select AllMap+_Category_VTOL+_SelectAll+",
			"select AllMap+_RulesParamEquals_role_scout+_SelectAll+",
			"select AllMap++_ClearSelection+",
			"attack",
		}) do
			assert.is_nil(Select.parse(action), action)
		end
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
		local command = Select.parse("select AllMap+_Builder_Not_Idle+_ClearSelection_SelectOne+")

		assert.are.equal(
			"[summary conclusion=[conclusion.SelectOne] filters=[filter.Builder][separator][not filter=[filter.Idle]] source=[source.AllMap]]",
			Select.describe(command, echo)
		)
	end)

	it("says so when the selection is added to rather than replaced", function()
		local command = Select.parse("select Visible++_SelectPart_50+")

		assert.are.equal(
			"[keepSelection summary=[summaryAll conclusion=[conclusion.SelectPart value=50] source=[source.Visible]]]",
			Select.describe(command, echo)
		)
	end)

	it("joins plain unit names as a choice where the first of them stood", function()
		local command = Select.parse(
			"select AllMap+_Idle_IdMatches_armcom_Not_IdMatches_legcom_IdMatches_corcom+_ClearSelection_SelectAll+"
		)

		assert.are.equal(
			"[summary conclusion=[conclusion.SelectAll] filters=[filter.Idle][separator][anyOf units=[filter.IdMatches value=armcom] last=[filter.IdMatches value=corcom]][separator][not filter=[filter.IdMatches value=legcom]] source=[source.AllMap]]",
			Select.describe(command, echo)
		)
	end)
end)

describe("what the builder can edit", function()
	it("refuses a filter named more often than it can hold", function()
		assert.is_false(Select.editable(Select.parse("select AllMap+_RelativeHealth_30_RelativeHealth_70+_SelectAll+")))
		assert.is_false(Select.editable(Select.parse("select AllMap+_Weapons_Not_Weapons+_SelectAll+")))
	end)
end)

describe("telling whether an edit changed a selection", function()
	it("reads reordered filters as the same selection and a changed value as another", function()
		assert.is_true(
			Select.sameSelection(
				"select AllMap+_Idle_Builder+_ClearSelection_SelectOne+",
				"select AllMap+_Builder_Idle+_ClearSelection_SelectOne+"
			)
		)
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

	it("checks every value it holds as the kind the engine reads", function()
		local builder = open("select FromMouse_150.5+_IdMatches_armcom+_ClearSelection_SelectNum_2.5+")
		assert.is_false(select(2, builder:command()))

		builder.conclusionArg:setText("2")
		assert.is_true(select(2, builder:command()))

		-- The engine ends a token at an underscore, so a scavenger or raptor name would split in two.
		builder:argFields("IdMatches", "is")[1]:setText("armcom_scav")
		assert.is_false(select(2, builder:command()))
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
			assert.is_true(Select.sameSelection(action, Select.format((open(action):command()))), action)
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

		local realMouse = env.Spring.GetMouseState
		env.Spring.GetMouseState = function()
			return g.x1 + 1, g.listY1 + 1
		end
		for _ = 1, #builder.order do
			builder:mouseWheel(true)
		end
		env.Spring.GetMouseState = realMouse

		assert.is_false(field:isFocused())
		assert.is_false(builder:textInput("9"))
	end)
end)
