if Spring.GetModOptions then
	local modOptions = Spring.GetModOptions()
	local modOptionsFile = VFS.Include("modoptions.lua")

	for _, modOption in ipairs(modOptionsFile) do
		local key = modOption.key

		if modOption.type ~= "section" then
			if modOptions[key] == nil then
				modOptions[key] = modOption.def
			end

			if (modOption.type == "bool") and (type(modOptions[key]) ~= "boolean") then
				local value = tonumber(modOptions[key])
				modOptions[key] = value == 1 and true or false
			end

			if modOption.type == "number" then
				modOptions[key] = tonumber(modOptions[key])
			end
		end
	end

	-- Prevent widgets from messing with each other's modoptions table.
	-- The native engine call does this by returning a new table each time but that is wasteful
	local readOnlyModOptions = {}
	setmetatable(readOnlyModOptions, {
		__index = modOptions,
		__newindex = function(t, k, v)
			error("attempt to update a read-only Spring.GetModOptions table", 2)
		end,
	})

	Spring.GetModOptions = function()
		return readOnlyModOptions
	end

	-- Returns a copy of the modOptions table. Slower, but allows iterating over
	-- the returned table using pairs/ipairs.
	GetModOptionsCopy = function()
		return table.copy(modOptions)
	end
end

if Spring.Echo then
	local echo = Spring.Echo
	local printOptions = { pretty = true }

	local function multiEcho(...)
		local n = select("#", ...)
		local firstTableIndex
		local tableCount = 0

		for index = 1, n do
			if type(select(index, ...)) == "table" then
				tableCount = tableCount + 1
				if not firstTableIndex then
					firstTableIndex = index
				end
			end
		end

		if tableCount == 0 then
			echo(...)
			return
		end

		-- When Spring.Echo is called with a single table parameter, engine will echo "TABLE: {value}",
		-- where {value} is whatever value happens to be the first value in the table
		if tableCount == 1 and n == 1 then
			echo("<table>")
		else
			echo(...)
		end

		local args = table.pack(...)
		for index = firstTableIndex, n do
			if type(args[index]) == "table" then
				echo(table.toString(args[index], printOptions))
			end
		end
	end

	Spring.Echo = multiEcho
end
