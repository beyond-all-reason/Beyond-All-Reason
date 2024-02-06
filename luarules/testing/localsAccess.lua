local localsDetectorString = [[

local __locals = {}
local __i = 1
while true do
  local name, _ = debug.getlocal(1, __i)
  if not name then break end

  if name ~= "__i" and name ~= "__locals" then
    table.insert(__locals, name)
  end

  __i = __i + 1
end
return __locals
]]

local function generateLocalsAccessStr(localsNames)
	local content = "\n__localsAccess = {\n"
	content = content .. "  getters = {\n"
	for _, name in ipairs(localsNames) do
		content = content .. "    " .. name .. " = function() return " .. name .. " end,\n"
	end
	content = content .. "  },\n"
	content = content .. "  setters = {\n"
	for _, name in ipairs(localsNames) do
		content = content .. "    " .. name .. " = function(__value) " .. name .. " = __value end,\n"
	end
	content = content .. "  },\n"
	content = content .. "}\n"
	return content
end

local function generateLocalsAccessMetatable(baseMetatable)
	return {
		__index = function(t, k)
			if t.__localsAccess and t.__localsAccess.getters[k] ~= nil then
				return t.__localsAccess.getters[k]()
			elseif baseMetatable and baseMetatable.__index ~= nil then
				if type(baseMetatable.__index) == "table" then
					return baseMetatable.__index[k]
				else
					return baseMetatable.__index(t, k)
				end
			else
				return rawget(t, k)
			end
		end,
		__newindex = function(t, k, v)
			if t.__localsAccess and t.__localsAccess.setters[k] ~= nil then
				return t.__localsAccess.setters[k](v)
			elseif baseMetatable and baseMetatable.__newindex ~= nil then
				return baseMetatable.__newindex(t, k, v)
			else
				return rawset(t, k, v)
			end
		end,
	}
end

--[[
example usage:

local function loadFileWithLocals(filename)
	local _, localsNames = loadFile(filename, localsDetectorString)
	local env, _ = loadFile(filename, generateLocalsAccessStr(localsNames))
	setmetatable(env, generateLocalsAccessMetatable(getmetatable(env)))

	return env
end
]]--

return {
	localsDetectorString = localsDetectorString,
	generateLocalsAccessStr = generateLocalsAccessStr,
	generateLocalsAccessMetatable = generateLocalsAccessMetatable,
}
