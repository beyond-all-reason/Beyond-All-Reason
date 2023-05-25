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

	local modOptionsCopy = table.copy(modOptions)
	Spring.GetModOptions = function()
		return modOptionsCopy
	end
end
