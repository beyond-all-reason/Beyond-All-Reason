function assertTablesEqual(table1, table2, margin, visited, path)
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



return {
	assertTablesEqual = assertTablesEqual,
}
