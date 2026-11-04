-- Guards which bindings the editor reads as sharing a key, per RecoilEngine's KeyBindings.cpp (read, not measured).

local Json = VFS.Include("common/luaUtilities/json.lua")
local keybindModel = VFS.Include("luaui/Include/keybind_model.lua")

local function meets(binds, action, raw, layout)
	local found = {}
	for _, other in ipairs(keybindModel.collidersOf(keybindModel.collisionIndex(binds, layout), action, raw)) do
		found[other.action] = other.first
	end

	return found
end

local function shippedProfile(name)
	local file = assert(io.open("common/configs/keybind_defaults.json", "r"))
	local defaults = Json.decode(file:read("*a"))
	file:close()

	for _, profile in ipairs(defaults.profiles) do
		if profile.name == name then
			return profile
		end
	end

	error("no shipped profile named " .. name)
end

local function azerty(scan)
	return ({ a = "q", q = "a" })[scan] or ""
end

local function bind(keyset, action)
	return { keyset = keyset, action = action }
end

describe("keybind collisions", function()
	it("puts an Any+ binding on the same key as every exact binding ending there", function()
		local binds = {
			bind("Any+x", "loose"),
			bind("x", "bare"),
			bind("Ctrl+x", "ctrl"),
			bind("Shift+Alt+x", "shiftAlt"),
		}

		assert.are.same({ bare = true, ctrl = true, shiftAlt = true }, meets(binds, "loose", "Any+x"))
		assert.are.same({ loose = false }, meets(binds, "ctrl", "Ctrl+x"))
	end)

	it("keeps exact bindings on different modifiers apart", function()
		local binds = { bind("Ctrl+x", "ctrl"), bind("Alt+x", "alt") }

		assert.are.same({}, meets(binds, "ctrl", "Ctrl+x"))
	end)

	it("drops the other modifiers from an Any+ keyset, as the engine does", function()
		local binds = { bind("Any+Ctrl+x", "written"), bind("Alt+x", "alt"), bind("Any+x", "loose") }

		assert.are.same({ alt = true, loose = false }, meets(binds, "written", "Any+Ctrl+x"))
	end)

	it("reads a modifier bound on its own as its Any+ form", function()
		local binds = { bind("shift", "bare"), bind("Any+shift", "loose") }

		assert.are.same({ loose = false }, meets(binds, "bare", "shift"))
	end)

	it("tries every exact binding before an Any+ one, whatever order they were bound in", function()
		local binds = { bind("Any+x", "loose"), bind("Ctrl+x", "ctrl") }

		assert.are.same({ ctrl = true }, meets(binds, "loose", "Any+x"))
		assert.are.same({ loose = false }, meets(binds, "ctrl", "Ctrl+x"))
	end)

	it("orders bindings within one tier by when they were bound", function()
		local binds = { bind("x", "earlier"), bind("x", "later") }

		assert.are.same({ earlier = true }, meets(binds, "later", "x"))
		assert.are.same({ later = false }, meets(binds, "earlier", "x"))
	end)

	it("needs the same taps before the last one in a chain", function()
		local binds = { bind("a,Any+x", "loose"), bind("a,Ctrl+x", "chained"), bind("b,Ctrl+x", "other") }

		assert.are.same({ chained = true }, meets(binds, "loose", "a,Any+x"))
	end)

	it("keeps a keycode and a scancode apart when there is no layout to pair them by", function()
		local binds = { bind("Any+x", "code"), bind("sc_x", "scan") }

		assert.are.same({}, meets(binds, "code", "Any+x"))
	end)

	it("puts a keycode and the scancode the layout gives it on one key", function()
		local binds = { bind("a", "code"), bind("sc_q", "scan"), bind("sc_a", "elsewhere") }

		assert.are.same({ scan = false }, meets(binds, "code", "a", azerty))
		assert.are.same({ code = true }, meets(binds, "scan", "sc_q", azerty))
	end)

	it("still needs the modifiers to agree between a keycode and a scancode", function()
		local binds = { bind("Ctrl+a", "ctrl"), bind("sc_q", "scan"), bind("Any+a", "loose") }

		assert.are.same({ loose = false }, meets(binds, "scan", "sc_q", azerty))
	end)

	it("leaves a scancode the layout cannot name as it is", function()
		local binds = { bind("a", "code"), bind("sc_f13", "scan") }

		assert.are.same({}, meets(binds, "scan", "sc_f13", azerty))
	end)

	it("finds holders of a key the action is not bound on yet", function()
		local binds = { bind("Any+x", "loose"), bind("Ctrl+x", "ctrl") }

		assert.are.same({ loose = false, ctrl = false }, meets(binds, "capturing", "Any+Ctrl+x"))
	end)

	it("names an action once however many of its bindings it meets through", function()
		local binds = { bind("Any+x", "loose"), bind("x", "twice"), bind("Ctrl+x", "twice") }

		local found = keybindModel.collidersOf(keybindModel.collisionIndex(binds), "loose", "Any+x")
		assert.are.equal(1, #found)
		assert.are.equal("twice", found[1].action)
	end)

	it("finds the exact bindings the Grid profile ships beside an Any+ one", function()
		local grid = shippedProfile("Grid")

		local found = meets(grid.binds, "selectbox_same", "Any+sc_z")
		assert.is_true(found["gridmenu_category 1"])
		assert.is_true(found["buildspacing inc"])
		assert.is_false(found["gridmenu_key 1 1"])
	end)
end)
