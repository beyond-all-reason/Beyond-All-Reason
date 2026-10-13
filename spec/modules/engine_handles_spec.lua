local Derive = require("tools/engine_handles/derive")
local EngineHandles = require("modules/engine_handles")

-- modules/engine_handles.lua is generated from the recoil-lua-library listings by tools/engine_handles/generate.lua.
-- This fails when the listings moved on without it.
describe("the generated engine handle sets", function()
	it("match the recoil-lua-library listings", function()
		local syncedOnly, unsyncedOnly = Derive.Sides()
		if syncedOnly == nil or unsyncedOnly == nil then
			pending("the recoil-lua-library listings are not checked out here", function() end)
			return
		end
		assert.are.same(
			Derive.Sorted(syncedOnly),
			EngineHandles.syncedOnly,
			"rerun: luajit tools/engine_handles/generate.lua"
		)
		assert.are.same(
			Derive.Sorted(unsyncedOnly),
			EngineHandles.unsyncedOnly,
			"rerun: luajit tools/engine_handles/generate.lua"
		)
	end)

	it("and so does the engine's type per handle, types/SpringHandles.lua", function()
		local syncedOnly, unsyncedOnly = Derive.Sides()
		if syncedOnly == nil or unsyncedOnly == nil then
			pending("the recoil-lua-library listings are not checked out here", function() end)
			return
		end
		local file = assert(io.open("types/SpringHandles.lua", "r"))
		local text = file:read("*a")
		file:close()
		-- stylua wraps the longer signatures; the checked-in file is the formatted one, so compare without whitespace
		local function squashed(s)
			return (s:gsub("%s", ""))
		end
		assert.are.equal(
			squashed(assert(Derive.RenderTypes(syncedOnly, unsyncedOnly))),
			squashed(text),
			"rerun: luajit tools/engine_handles/generate.lua, then stylua on types/SpringHandles.lua"
		)
	end)
end)
