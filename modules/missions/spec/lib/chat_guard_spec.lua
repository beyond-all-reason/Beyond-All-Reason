local ChatGuard = VFS.Include("modules/missions/lib/chat_guard.lua")

describe("mission chat guard", function()
	it("always allows singleplayer", function()
		assert.is_true(ChatGuard.IsAllowed(true, false))
		assert.is_true(ChatGuard.IsAllowed(true, true))
	end)

	it("allows multiplayer only with cheats enabled", function()
		assert.is_true(ChatGuard.IsAllowed(false, true))
		assert.is_false(ChatGuard.IsAllowed(false, false))
	end)

	it("treats missing facts as denial, not permission", function()
		assert.is_false(ChatGuard.IsAllowed(nil, nil))
		assert.is_false(ChatGuard.IsAllowed(nil, false))
	end)
end)
