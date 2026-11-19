describe("KEYSYMS deprecation proxy", function()
	-- busted runs on stock LuaJIT, which never checks __pairs from the real
	-- pairs() global (only the engine's patched Lua does), so these tests call
	-- the metamethod directly instead of going through pairs().
	local function iterate(t)
		local iter, state, initial = getmetatable(t).__pairs(t)
		local seen = {}
		for key, value in iter, state, initial do
			seen[key] = value
		end
		return seen
	end

	-- keybind_keysyms.lua includes keysym.h.lua into a bare {} env with no
	-- globals at all, same as the engine's bare-env include does. That's the
	-- setup #3528 crashed on once keysym.h.lua started calling setmetatable().
	it("crashes when loaded into a bare env with no setmetatable", function()
		assert.has_error(function()
			VFS.Include("luaui/Headers/keysym.h.lua", {}, VFS.ZIP)
		end)
	end)

	it("hands back the original SDL1.2 values via require, without crashing", function()
		local KEYSYMS = require("luaui/Include/keybind_keysyms")

		assert.are.equal(32, KEYSYMS.SPACE)
		assert.are.equal(13, KEYSYMS.RETURN)
	end)

	it("still iterates every key via the __pairs metamethod", function()
		local KEYSYMS = require("luaui/Include/keybind_keysyms")
		local seen = iterate(KEYSYMS)

		assert.are.equal(32, seen.SPACE)
		assert.are.equal(13, seen.RETURN)
	end)

	-- Without __newindex the write would land on the (empty) proxy table itself:
	-- the read-back would still pass by accident, but the key would stay invisible
	-- to __pairs, which only ever walks the real value table.
	it("keeps a written key visible through both read and iteration", function()
		local KEYSYMS = require("luaui/Include/keybind_keysyms")
		KEYSYMS.CUSTOM_TEST_KEY = 999

		assert.are.equal(999, KEYSYMS.CUSTOM_TEST_KEY)
		assert.are.equal(999, iterate(KEYSYMS).CUSTOM_TEST_KEY)
	end)
end)
