local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local noop = function() end

-- What the keys under the player's fingers read as.
local held = {}

-- A fresh model over a small keymap, told what a window is told.
local function newModel(bindings)
	local env = SpecEnv.new({
		-- The store's files are not there; the shipped ones are read.
		VFS = {
			LoadFile = function(path)
				local file = io.open(path, "rb")
				if not file then
					return nil
				end
				local contents = file:read("*a")
				file:close()
				return contents
			end,
		},
		io = {
			open = function(path, mode)
				if mode == "w" then
					return nil
				end
				return io.open(path, mode)
			end,
		},
		Spring = {
			GetKeyBindings = function()
				return bindings
			end,
			GetKeyCode = function()
				return 1
			end,
			GetKeyFromScanSymbol = function(symbol)
				return symbol
			end,
			GetConfigString = function(_, default)
				return default
			end,
			SetConfigString = noop,
			Echo = noop,
			GetTimer = function()
				return 0
			end,
			DiffTimers = function()
				return 0
			end,
			GetModKeyState = function()
				return held.alt, held.ctrl, false, held.shift
			end,
			GetScanSymbol = function()
				return "sc_j"
			end,
			GetClipboard = function()
				return ""
			end,
			SetClipboard = noop,
		},
		math = {
			isInRect = function(x, y, x1, y1, x2, y2)
				return x >= x1 and x <= x2 and y >= y1 and y <= y2
			end,
		},
		WG = {},
		UnitDefNames = {},
		BAR = {
			I18N = function(key, params)
				if params and params.default ~= nil then
					return params.default
				end
				return key
			end,
		},
	})
	local model = SpecEnv.include(env, "luaui/Include/keybind_editor_model.lua")
	local told = { scrolledToTop = 0, built = 0 }
	model.view.layout = noop
	model.view.rowsChanged = function()
		told.built = told.built + 1
	end
	model.view.scrollToTop = function()
		told.scrolledToTop = told.scrolledToTop + 1
	end
	model.refresh()
	return model, told, env
end

local function bindings()
	return {
		{ command = "wait", extra = "", boundWith = "sc_w" },
		{ command = "stop", extra = "", boundWith = "sc_s" },
		{ command = "mine_only", extra = "arg", boundWith = "sc_k" },
	}
end

local function rowFor(model, action)
	for _, row in ipairs(model.rows) do
		if row.action == action then
			return row
		end
	end
end

describe("the keybind editor's model", function()
	describe("the row list", function()
		it("lists an action nothing in the catalog names under Other, by its own id", function()
			local model = newModel(bindings())

			assert.is_truthy(rowFor(model, "mine_only arg"))
			assert.is_true(rowFor(model, "mine_only arg").custom)
		end)

		it("narrows to what the search names", function()
			local model = newModel(bindings())

			model.searchBox:setText("mine_only")

			assert.is_truthy(rowFor(model, "mine_only arg"))
			assert.is_nil(rowFor(model, "wait"))
		end)

		it("puts rows found by key on top, under their own heading", function()
			local model = newModel(bindings())

			model.searchBox:setText("k")

			assert.are.equal("header", model.rows[1].type)
			assert.are.equal("ui.keybinds.editor.boundTo", model.rows[1].text)
			assert.are.equal("mine_only arg", model.rows[2].action)
		end)

		it("goes back to the top for a category picked", function()
			local model, told = newModel(bindings())
			local before = told.scrolledToTop

			model.selectCategory("categories.other")

			assert.are.equal("categories.other", model.selectedCategory)
			assert.are.equal(before + 1, told.scrolledToTop)
		end)
	end)

	describe("staging", function()
		it("takes a capture's key as an edit, and Ctrl+Z takes it back", function()
			local model = newModel(bindings())

			model.startCapture("wait", "Wait")
			model.keyPress(106, 30)
			assert.are.equal("sc_j", model.chainRaw())
			model.commitCapture(model.chainRaw())

			assert.is_true(model.dirty)
			assert.are.equal(2, #model.working.byAction.wait)

			held.ctrl = true
			model.keyPress(require("luaui/Include/keybind_keysyms").Z, 1)
			held.ctrl = false

			assert.is_false(model.dirty)
			assert.are.equal(1, #model.working.byAction.wait)
		end)

		it("rewrites a binding in place, so the keys tried first stay first", function()
			local model = newModel(bindings())

			model.startCapture("wait", "Wait", "sc_w")
			model.keyPress(106, 30)
			model.commitCapture(model.chainRaw())

			local actions = {}
			for i, b in ipairs(model.working.binds) do
				actions[i] = b.action .. "=" .. b.keyset
			end
			assert.are.same({ "wait=sc_j", "stop=sc_s", "mine_only arg=sc_k" }, actions)
		end)

		it("does not call a capture accepted unchanged an edit", function()
			local model = newModel(bindings())

			model.startCapture("wait", "Wait", "sc_j")
			model.commitCapture("sc_j")

			assert.is_false(model.dirty)
		end)

		it("files one undo step for a chip standing for several binds", function()
			local model = newModel({
				{ command = "wait", extra = "", boundWith = "sc_w" },
				{ command = "wait", extra = "", boundWith = "Any+sc_w" },
			})

			model.handleZone("remove", "wait", "Wait", { "sc_w", "Any+sc_w" })

			assert.are.equal(1, #model.undo)
			assert.are.equal(0, #model.working.byAction.wait)
		end)
	end)

	describe("the capture", function()
		it("names held modifiers first, as a chip prints them", function()
			local model = newModel(bindings())

			model.startCapture("wait", "Wait")
			held.ctrl, held.shift = true, true
			model.keyPress(106, 30)
			held.ctrl, held.shift = false, false

			assert.are.equal("Ctrl+Shift+sc_j", model.chainRaw())
		end)

		it("has nothing to accept until a key was pressed", function()
			local model = newModel(bindings())

			model.startCapture("stop", "Stop", "sc_s")
			assert.is_false(model.captureCanAccept())

			model.keyPress(106, 30)
			assert.is_true(model.captureCanAccept())
		end)

		it("lets Escape go without an edit", function()
			local model = newModel(bindings())

			model.startCapture("wait", "Wait")
			model.keyPress(27, 1)

			assert.is_nil(model.capturing)
			assert.is_false(model.dirty)
		end)
	end)

	describe("the dialogs", function()
		it("asks before staged edits are left", function()
			local model = newModel(bindings())
			local went = false
			model.startCapture("wait", "Wait")
			model.keyPress(106, 30)
			model.commitCapture(model.chainRaw())

			assert.is_false(model.guardDirty(function()
				went = true
			end))
			assert.is_false(went)
			assert.are.equal("ui.keybinds.editor.unsavedTitle", model.dialog.title)

			model.middleDialog()

			assert.is_true(went)
			assert.is_false(model.dirty)
			assert.is_nil(model.dialog)
		end)

		it("goes ahead at once with nothing staged", function()
			local model = newModel(bindings())
			local went = false

			assert.is_true(model.guardDirty(function()
				went = true
			end))
			assert.is_true(went)
		end)

		it("will not take a preset's name that is taken, nor an empty one", function()
			local model = newModel(bindings())
			model.startDuplicate()

			model.nameBox:setText(model.profiles.builtins[1].name)
			assert.is_true(select(2, model.dialogName()))

			model.nameBox:setText("   ")
			assert.is_true(select(2, model.dialogName()))

			model.nameBox:setText("mine")
			assert.is_false(select(2, model.dialogName()))
		end)

		it("cancels an open modal on close, so its rollback runs", function()
			local model = newModel(bindings())
			local rolledBack = false
			model.startCapture("wait", "Wait")
			model.keyPress(106, 30)
			model.commitCapture(model.chainRaw())
			model.guardDirty(noop, function()
				rolledBack = true
			end)

			model.blur()

			assert.is_true(rolledBack)
			assert.is_nil(model.dialog)
		end)
	end)

	describe("the tooltips", function()
		it("lists what else a chip's key drives, by section and name", function()
			local model = newModel({
				{ command = "wait", extra = "", boundWith = "sc_w" },
				{ command = "stop", extra = "", boundWith = "sc_w" },
			})

			local content, title = model.rowTip(rowFor(model, "wait"), "chip", { raws = { "sc_w" }, display = "W" })

			assert.are.equal(rowFor(model, "wait").label, title)
			assert.are.equal(2, #content.rows)
			assert.are.equal(model.labels.stop or "stop", content.rows[2][2])
			assert.is_truthy(content.note)
		end)

		it("says what a press on the hollow chip puts back, untitled", function()
			local model = newModel(bindings())
			local row = rowFor(model, "wait")
			row.change = {}

			local content, title = model.rowTip(row, "revert")

			assert.is_nil(title)
			assert.are.equal("ui.keybinds.editor.revertTooltip", content.text)
		end)

		it("calls a shipped preset a default", function()
			local model = newModel(bindings())

			local content = model.presetTip(model.profiles.builtins[1].name)

			assert.are.equal("ui.keybinds.editor.presetDefault", content.note)
		end)

		it("says Changed has nothing to compare with when nothing is picked", function()
			local model = newModel(bindings())
			model.base = nil

			assert.are.equal("ui.keybinds.editor.changedNoneTooltip", model.changedTip().note)
		end)

		it("wraps a copy, and gives nil for a tooltip that says nothing", function()
			local model = newModel(bindings())
			local font = {
				WrapText = function(_, s)
					return s .. "|"
				end,
			}
			local content = { text = "a", rows = { { "x", "y" } } }

			local wrapped = model.wrapTip(content, font, 100)

			assert.are.equal("a|", wrapped.text)
			assert.are.equal("a", content.text)
			assert.are.equal(content.rows, wrapped.rows)
			assert.is_nil(model.wrapTip({}, font, 100))
			assert.is_nil(model.wrapTip(nil, font, 100))
		end)
	end)

	describe("the actions", function()
		it("leaves Save alone with nothing staged, and opens Duplicate's name dialog", function()
			local model = newModel(bindings())

			model.pressButton("save")
			assert.is_nil(model.dialog)

			model.pressButton("duplicate")
			assert.is_truthy(model.dialog)
		end)

		it("opens a command row's text for editing on a press on its name", function()
			local model = newModel(bindings())

			model.pressLabel(rowFor(model, "mine_only arg"))

			assert.is_truthy(model.dialog)
			assert.is_true(model.dialog.freeText)
		end)

		it("moves a held row only among those it shares its order with", function()
			local model = newModel(bindings())
			model.rows = { { reorder = "a", id = 1 }, { reorder = "a", id = 2 }, { reorder = "b", id = 3 } }
			local gen = model.rowsGen

			assert.are.same({ 1, 2 }, { model.reorderSpan(2) })
			assert.are.same({ 3, 3 }, { model.reorderSpan(3) })

			model.moveRow(1, 2)

			assert.are.same({ 2, 1, 3 }, { model.rows[1].id, model.rows[2].id, model.rows[3].id })
			assert.are.equal(gen + 1, model.rowsGen)
		end)

		it("shows a keyboard key's rows by searching for it, from the top", function()
			local model, told = newModel(bindings())
			model.selectedCategory = "categories.other"
			local before = told.scrolledToTop

			model.showKey({ label = "K", searchName = "k" }, "")

			assert.is_nil(model.selectedCategory)
			assert.are.equal(before + 1, told.scrolledToTop)
			assert.are.equal("k", model.searchBox:getText())
			assert.are.equal("mine_only arg", model.rows[2].action)
		end)
	end)

	describe("the keyboard while open", function()
		it("takes the text once, and gives it back on close", function()
			local model = newModel(bindings())
			local owned, disowned = 0, 0
			local function own()
				owned = owned + 1
				return true
			end
			local function disown()
				disowned = disowned + 1
			end

			model.holdInput(true, own, disown)
			model.holdInput(true, own, disown)
			assert.are.equal(1, owned)

			model.holdInput(false, own, disown)
			model.holdInput(false, own, disown)
			assert.are.equal(1, disowned)
		end)

		it("asks chat to let go when chat holds the text", function()
			local model, _, env = newModel(bindings())
			local asked = {}
			local free = false
			env.WG.chat = {
				isInputActive = function()
					return not free
				end,
				setHandleInput = function(on)
					asked[#asked + 1] = on
					free = true
				end,
			}

			model.holdInput(true, function()
				return free
			end, noop)

			assert.are.same({ false, true }, asked)
		end)

		it("lets the release of a key held at opening through, once", function()
			local model, _, env = newModel(bindings())
			env.Spring.GetPressedKeys = function()
				return { [33] = true }
			end

			model.holdInput(true, function()
				return true
			end, noop)

			assert.is_true(model.releaseGoesThrough(33))
			assert.is_false(model.releaseGoesThrough(33))
			assert.is_false(model.releaseGoesThrough(44))
		end)
	end)
end)
