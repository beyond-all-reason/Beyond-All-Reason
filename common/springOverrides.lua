if Spring.GetModOptions then
	local modOptions = Spring.GetModOptions()
	local modOptionsFile = VFS.Include('modoptions.lua')

	for _, modOption in ipairs(modOptionsFile) do
		local key = modOption.key

		if modOption.type ~= "section" then
			if modOptions[key] == nil then
				modOptions[key] = modOption.def
			end

			if (modOption.type == 'bool') and (type(modOptions[key]) ~= 'boolean') then
				local value = tonumber(modOptions[key])
				modOptions[key] = value == 1 and true or false
			end

			if modOption.type == 'number' then
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
			end
	})

	Spring.GetModOptions = function ()
		return readOnlyModOptions
	end

	-- Returns a copy of the modOptions table. Slower, but allows iterating over
	-- the returned table using pairs/ipairs.
	Spring.GetModOptionsCopy = function ()
		return table.copy(modOptions)
	end
end

if Spring.Echo then
	local echo = Spring.Echo
	local printOptions = { pretty = true }

	local function multiEcho(...)
		local args = table.pack(...)
		local tableIndexes = {}

		for index = 1, args.n do
			local value = args[index]

			if type(value) == 'table' then
				table.insert(tableIndexes, index)
			end
		end

		-- When Spring.Echo is called with a single table parameter, engine will echo "TABLE: {value}",
		-- where {value} is whatever value happens to be the first value in the table
		if #tableIndexes == 1 and args.n == 1 then
			echo("<table>")
		else
			echo(unpack(args, 1, args.n))
		end

		for _, index in ipairs(tableIndexes) do
			echo(table.toString(args[index], printOptions))
		end
	end

        Spring.Echo = multiEcho
end

-- Disable widget issued unit orders
local environment = Script.GetName and Script.GetName()
if environment == "LuaUI" and Spring.GiveOrderToUnit then
    local function disabledOrder()
        Spring.Echo("Widget issued unit order blocked")
        return false
    end

    Spring.GiveOrder = disabledOrder
    Spring.GiveOrderToUnit = disabledOrder
    Spring.GiveOrderToUnitArray = disabledOrder
    Spring.GiveOrderArrayToUnit = disabledOrder
    Spring.GiveOrderArrayToUnitArray = disabledOrder
end
