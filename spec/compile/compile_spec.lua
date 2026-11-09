-- Lua sources have to compile within the specific limits of a virtual stack machine.
-- Per function, those are generally: 200 locals, 60 upvalues, and 250 stack slots.

---@type table<string?, true>
local NOT_VALID_LUA = {
	["mapgenerator/mapinfo_template.lua"] = true,
}

describe("Lua sources", function()
	it("compile within the engine's limits", function()
		local compiled = 0
		local failures = {}
		local files = io.popen('git ls-files -- "*.lua"')
		for path in files:lines() do
			if not NOT_VALID_LUA[path] then
				local chunk, message = loadfile(path)
				if chunk then
					compiled = compiled + 1
				else
					failures[#failures + 1] = message
				end
			end
		end
		files:close()

		assert.are.same({}, failures)
		assert.is_true(compiled > 0, "git listed no Lua files")
	end)
end)
