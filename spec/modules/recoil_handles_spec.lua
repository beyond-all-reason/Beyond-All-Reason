local ModuleEnv = require("modules/module_env")

-- common/recoil/{shared,synced,unsynced}.lua return the engine as one handle sees it (ModuleEnv.Handle): the same
-- proxy a module file's Spring is, for a file of any kind, typed by the file's return.
describe("the engine per handle, for any file", function()
	local root ---@type table a state that registers both handles, as the harness does

	before_each(function()
		root = {
			Spring = {
				GetGameFrame = function()
					return 7
				end,
				CreateUnit = function()
					return "unit"
				end,
				GetMouseState = function()
					return "mouse"
				end,
			},
		}
	end)

	it("synced may call the synced handle's, not the unsynced handle's", function()
		local Spring = ModuleEnv.Handle("synced", root)
		assert.are.equal(7, Spring.GetGameFrame())
		assert.are.equal("unit", Spring.CreateUnit())
		assert.error_matches(
			function()
				return Spring.GetMouseState()
			end,
			'a file holding require%("common/recoil/synced"%) calls Spring.GetMouseState, which the engine offers in the unsynced handle only; this file runs in the synced handle'
		)
	end)

	it("unsynced the reverse", function()
		local Spring = ModuleEnv.Handle("unsynced", root)
		assert.are.equal("mouse", Spring.GetMouseState())
		assert.error_matches(
			function()
				return Spring.CreateUnit()
			end,
			'a file holding require%("common/recoil/unsynced"%) calls Spring.CreateUnit, which the engine offers in the synced handle only; this file runs in the unsynced handle'
		)
	end)

	it("shared may call neither handle's own", function()
		local Spring = ModuleEnv.Handle("shared", root)
		assert.are.equal(7, Spring.GetGameFrame())
		assert.error_matches(function()
			return Spring.CreateUnit()
		end, "this file runs in either handle")
		assert.error_matches(function()
			return Spring.GetMouseState()
		end, "this file runs in either handle")
	end)

	it("a write is refused", function()
		local Spring = ModuleEnv.Handle("synced", root)
		assert.error_matches(function()
			Spring.Echo = print
		end, "writes Spring.Echo")
	end)

	it("is one proxy per handle per state", function()
		assert.are.equal(ModuleEnv.Handle("synced", root), ModuleEnv.Handle("synced", root))
		assert.are_not.equal(ModuleEnv.Handle("synced", root), ModuleEnv.Handle("unsynced", root))
		assert.are_not.equal(ModuleEnv.Handle("synced", root), ModuleEnv.Handle("synced", { Spring = root.Spring }))
	end)

	it("a handle's view required in the other handle's state is an error at the require", function()
		local unsyncedState = { Spring = { GetMouseState = function() end } }
		assert.error_matches(function()
			ModuleEnv.Handle("synced", unsyncedState)
		end, "common/recoil/synced required in the unsynced handle")
		assert.has_no_error(function()
			ModuleEnv.Handle("unsynced", unsyncedState)
		end)
		-- a state that registers neither (a parser, the harness) refuses nothing at the require
		assert.has_no_error(function()
			ModuleEnv.Handle("synced", { Spring = {} })
		end)
	end)

	it("the common/recoil files return the state's proxies", function()
		assert.are.equal(ModuleEnv.Handle("synced"), require("common/recoil/synced"))
		assert.are.equal(ModuleEnv.Handle("unsynced"), require("common/recoil/unsynced"))
		assert.are.equal(ModuleEnv.Handle("shared"), require("common/recoil/shared"))
	end)
end)
