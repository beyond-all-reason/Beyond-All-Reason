-- Lua sources have to compile within the specific limits of a virtual stack machine.
-- Per function, those are generally: 200 locals, 60 upvalues, and 250 stack slots.

local lfs = require("lfs")

---@type table<string?, true>
local NOT_VALID_LUA = {
	["mapgenerator/mapinfo_template.lua"] = true,
}

local function addLuaFiles(directory, files)
	for name in lfs.dir(directory) do
		local path = directory == "." and name or directory .. "/" .. name
		local mode = lfs.attributes(path, "mode")
		if mode == "file" then
			if name:match("%.lua$") then
				files[#files + 1] = path
			end
		elseif mode == "directory" and name ~= "." and name ~= ".." and name ~= ".git" and name ~= ".lux" then
			-- git lists none of a nested repository's files, such as a submodule's
			if not lfs.attributes(path .. "/.git") then
				addLuaFiles(path, files)
			end
		end
	end
	return files
end

describe("Lua sources", function()
	it("compile within the engine's limits", function()
		local compiled = 0
		local failures = {}
		local files = addLuaFiles(".", {})
		table.sort(files)
		for _, path in ipairs(files) do
			if not NOT_VALID_LUA[path] then
				local chunk, message = loadfile(path)
				if chunk then
					compiled = compiled + 1
				else
					failures[#failures + 1] = message
				end
			end
		end

		assert.are.same({}, failures)
		assert.is_true(compiled > 0, "found no Lua files")
	end)
end)
