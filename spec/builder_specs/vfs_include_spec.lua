describe("VFS.Include mock", function()
	local path = "spec/builders/index.lua"

	it("returns a fresh table on every call, as the engine does", function()
		local first = VFS.Include(path)
		local second = VFS.Include(path)

		assert.is_table(first)
		assert.is_table(second)
		assert.is_false(rawequal(first, second))
	end)

	it("does not leak one caller's environment into the next", function()
		local sandbox = setmetatable({}, { __index = _G })
		VFS.Include(path, sandbox)

		assert.is_table(VFS.Include(path))
	end)

	it("keeps a nested include of a path already being included isolated", function()
		local outer = setmetatable({ marker = "outer" }, { __index = _G })

		local reentrant = VFS.Include("spec/fixtures/reentrant_include.lua", outer)

		assert.are.equal("outer", reentrant.before)
		assert.are.equal("outer", reentrant.after)
	end)
end)
