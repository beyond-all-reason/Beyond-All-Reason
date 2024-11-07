--[[
usage:
* load file with localsDetectorString appended. when loaded, it will return a list of local variable names
* load the file again, with generateLocalsAccessStr(localsNames)) appended.
* setmetatable on the new environment to generateLocalsAccessMetatable(<old_metatable>)
Through the metatable, local variables within the loaded file will now be accessible as if they were globals
]]--

local localsDetectorString = [[

do
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
end
]]

local function generateLocalsAccessStr(localsNames)
	local content = "\n__localsAccess = {\n"

	content = content .. "\tgetters = {\n"
	for _, name in ipairs(localsNames) do
		content = content .. "\t\t" .. name .. " = function() return " .. name .. " end,\n"
	end
	content = content .. "\t},\n"

	content = content .. "\tsetters = {\n"
	for _, name in ipairs(localsNames) do
		content = content .. "\t\t" .. name .. " = function(__value) " .. name .. " = __value end,\n"
	end
	content = content .. "\t},\n"

	content = content .. "\tgetAllLocals = function() return {\n"
	for _, name in ipairs(localsNames) do
		content = content .. "\t\t\"" .. name .. "\",\n"
	end
	content = content .. "\t} end,\n"

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

return {
	localsDetectorString = localsDetectorString,
	generateLocalsAccessStr = generateLocalsAccessStr,
	generateLocalsAccessMetatable = generateLocalsAccessMetatable,
}
