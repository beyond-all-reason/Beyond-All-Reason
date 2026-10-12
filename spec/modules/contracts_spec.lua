local ModuleHandler = require("modules/module_handler")

-- A contract is asked for once, into a local typed as the module's contract, so that what a caller reaches through it is
-- typed: the checker sees the policy, and references from a policy's steps reach the caller. Read inline off the loader,
-- ModuleHandler.Contract(Modules.X).Y is a field of a table and reaches nothing.

---@param dir string
---@return string[]
local function luaFilesUnder(dir)
	local files = {}
	local handle = io.popen("find " .. dir .. " -name '*.lua' -not -path '*/spec/*' | sort") --[[@as any]]
	for line in handle:lines() do
		files[#files + 1] = line
	end
	handle:close()
	return files
end

describe("a module's contract, as its callers hold it", function()
	it("is held in a typed local, never read inline off the loader", function()
		ModuleHandler.ResetCaches()
		local inline = {}
		for _, manifest in pairs(ModuleHandler.Register()) do
			for _, path in ipairs(luaFilesUnder(manifest.dir)) do
				local file = io.open(path, "r")
				local text = file and file:read("*a") or ""
				if file then
					file:close()
				end
				for line in text:gmatch("[^\\n]+") do
					if line:find("Contract%(Modules%.%w+%)%.") then
						inline[#inline + 1] = path .. ": " .. line:gsub("^%s+", "")
					end
				end
			end
		end
		assert.are.same({}, inline)
	end)
end)
