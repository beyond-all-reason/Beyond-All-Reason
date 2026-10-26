-- modules/engine_handles.lua is recoil-lua-library/handles/generated/names.lua, copied in because the game archive
-- leaves the submodule out (springignore.txt). The nightly submodule update copies it again; this fails when a
-- submodule bump left the copy behind.
local LIBRARY = "recoil-lua-library/handles/generated/names.lua"
local COPY = "modules/engine_handles.lua"

local function text(path)
	local f = io.open(path, "r")
	if f == nil then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return (s:gsub("\r\n", "\n")) -- the checkout is CRLF
end

describe("modules/engine_handles.lua", function()
	it("is the library's names per handle", function()
		local library = text(LIBRARY)
		if library == nil then
			pending(LIBRARY .. " is not checked out here", function() end)
			return
		end
		assert.are.equal(library, text(COPY), "rerun: cp " .. LIBRARY .. " " .. COPY)
	end)
end)
