local function assertTablesEqual(table1, table2, margin, visited, path)
	visited = visited or {}
	path = path or {}
	margin = margin or 0

	local function buildPathString()
		local pathString = ""
		for _, key in ipairs(path) do
			pathString = pathString .. "[" .. tostring(key) .. "]"
		end
		return pathString
	end

	if type(table1) ~= "table" or type(table2) ~= "table" then
		if type(table1) == "number" and type(table2) == "number" then
			assert(math.abs(table1 - table2) <= margin, "Numbers are not close enough at path: " .. buildPathString())
		else
			assert(table1 == table2, "Tables are not equal at path: " .. buildPathString())
		end
		return
	end

	if visited[table1] or visited[table2] then
		-- Prevent infinite recursion on circular references
		assert(table1 == table2, "Tables are not equal (circular reference) at path: " .. buildPathString())
		return
	end

	visited[table1] = true
	visited[table2] = true

	for key, value1 in pairs(table1) do
		local value2 = table2[key]
		table.insert(path, key)
		assertTablesEqual(value1, value2, margin, visited, path)
		table.remove(path)
	end

	for key, value2 in pairs(table2) do
		local value1 = table1[key]
		if value1 == nil then
			assert(false, "Tables are not equal, extra key '" .. tostring(key) .. "' in second table at path: " .. buildPathString())
		end
	end
end

local depth = 0

-- Assert the given fn returns trueish before seconds.
--
-- fn will be called every 'frames' game frames.
-- errorMsg can be set to customize the error message preface.
local function assertSuccessBefore(seconds, frames, fn, errorMsg, depthOffset)
	local iters = math.ceil((seconds*30)/frames)
	for i=1, iters do
		-- dangerous to set depth here since fn() can fail.
		-- no pcall since SyncedProxy and SyncedRun wouldn't work.
		local res = fn()
		if res then
			return
		end
		Test.waitFrames(frames)
	end
	depthOffset = (depthOffset or 0) + 2 + depth
	-- Error instead of assert to get a proper error line position
	error(errorMsg or "assertSuccessBefore: didn't succeed before " .. tostring(seconds) .. " seconds", depthOffset)
end


-- Assert the given function throws an exception
--
-- Note it's better to use assertThrowsMessage since otherwise you might be catching an
-- unexpected error. Still, this is provided for convenience.
-- Can't be used with SyncedProxy or SyncedRun for now as they don't work inside pcall.
local function assertThrows(fn, errorMsg, depthOffset)
	depth = depth + 1
	local isOk = pcall(fn)
	depth = depth - 1
	if isOk then
		depthOffset = (depthOffset or 0) + 2 + depth
		error(errorMsg or "assertThrows", depthOffset)
	end
end


-- Assert the given function throws an exception with a specific error message
--
-- Can't be used with SyncedProxy or SyncedRun for now as they don't work inside pcall.
local function assertThrowsMessage(fn, testMsg, errorMsg, depthOffset)
	depthOffset = depthOffset or 0
	depth = depth + 1
	local isOk, result = pcall(fn)
	depth = depth - 1
	depthOffset = (depthOffset or 0) + 2 + depth
	if isOk then
		error(errorMsg or "assertThrowsMessage: didn't throw", depthOffset)
	end
	if not isOk and not type(result) == "string" then
		error(errorMsg or "assertThrowsMessage: error was not a string", depthOffset)
	end
	-- split "standard" error format
	-- it's in the form: [string "LuaUI/tests/selftests/test_assertions.lua"]:17: error2
	local match = result
	local errorIndex = result:match'^%[string "[%p%a%s]*%"]:[%d]+:().*'
	if errorIndex and errorIndex > 0 then
		match = result:sub(errorIndex + 1)
	end
	if match ~= testMsg then
		error(errorMsg or "assertThrowsMessage: error was not '" .. tostring(testMsg) .. "': '" .. tostring(match) .. "'", depthOffset)
	end
end

return {
	assertTablesEqual = assertTablesEqual,
	assertSuccessBefore = assertSuccessBefore,
	assertThrows = assertThrows,
	assertThrowsMessage = assertThrowsMessage,
}
