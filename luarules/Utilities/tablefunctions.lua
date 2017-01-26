Spring.Utilities = Spring.Utilities or {}

------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- bool deep: clone subtables. defaults to false. not safe with circular tables!
function Spring.Utilities.CopyTable(tableToCopy, deep)
	local copy = {}
	for key, value in pairs(tableToCopy) do
		if (deep and type(value) == "table") then
			copy[key] = Spring.Utilities.CopyTable(value, true)
		else
			copy[key] = value
		end
	end
	return copy
end

function Spring.Utilities.MergeTable(primary, secondary, deep)
	local new = Spring.Utilities.CopyTable(primary, deep)
	for i, v in pairs(secondary) do
		-- key not used in primary, assign it the value at same key in secondary
		if not new[i] then
			if (deep and type(v) == "table") then
				new[i] = Spring.Utilities.CopyTable(v, true)
			else
				new[i] = v
			end
		-- values at key in both primary and secondary are tables, merge those
		elseif type(new[i]) == "table" and type(v) == "table"  then
			new[i] = Spring.Utilities.MergeTable(new[i], v, deep)
		end
	end
	return new
end