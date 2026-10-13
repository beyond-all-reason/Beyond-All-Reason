local Derive = require("tools/engine_handles/derive")
local EngineHandles = require("modules/engine_handles")

-- modules/engine_handles.lua is generated from the engine's library per handle under types/recoil/generated/ by
-- tools/engine_handles/generate.lua. This fails when the types moved on without it.
describe("the generated engine handle sets", function()
	it("match the library per handle under types/recoil/generated/", function()
		local syncedOnly, unsyncedOnly = Derive.Sides()
		local syncedGlobals, unsyncedGlobals = Derive.Globals()
		if syncedOnly == nil or unsyncedOnly == nil or syncedGlobals == nil or unsyncedGlobals == nil then
			pending("types/recoil/ is not checked out here", function() end)
			return
		end
		local rerun = "rerun: luajit tools/engine_handles/generate.lua"
		assert.are.same(Derive.Sorted(syncedOnly), EngineHandles.syncedOnly, rerun)
		assert.are.same(Derive.Sorted(unsyncedOnly), EngineHandles.unsyncedOnly, rerun)
		assert.are.same(Derive.Sorted(syncedGlobals), EngineHandles.syncedOnlyGlobals, rerun)
		assert.are.same(Derive.Sorted(unsyncedGlobals), EngineHandles.unsyncedOnlyGlobals, rerun)
	end)

	it("and the vendored library declares the type per handle", function()
		local function text(file)
			local f = assert(io.open("types/recoil/" .. file, "r"))
			local s = f:read("*a")
			f:close()
			return (s:gsub("\r\n", "\n")) -- the checkout is CRLF, the shape below is written LF
		end
		local spring = text("Spring.lua")
		local shared, synced, unsynced =
			text("generated/shared.lua"), text("generated/synced.lua"), text("generated/unsynced.lua")
		assert.truthy(spring:find("\n---@class Recoil : Recoil.Synced, Recoil.Unsynced\n", 1, true), "the union")
		assert.truthy(spring:find("\n---@type Recoil\nSpring = {}", 1, true), "Spring is the union")
		assert.truthy(shared:find("\n---@class Recoil.Shared\nlocal Spring = {}\n", 1, true), "the shared view")
		assert.truthy(
			synced:find("\n---@class Recoil.Synced : Recoil.Shared\nlocal Spring = {}\n", 1, true),
			"the synced view extends shared"
		)
		assert.truthy(
			unsynced:find("\n---@class Recoil.Unsynced : Recoil.Shared\nlocal Spring = {}\n", 1, true),
			"the unsynced view extends shared"
		)
	end)
end)
