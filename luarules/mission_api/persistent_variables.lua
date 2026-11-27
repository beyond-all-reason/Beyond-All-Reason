---
--- Persistent variables are saved with campaign progress and written back out when the mission ends.
---

local function collectPersistentVariables()
	-- Saved values that this mission doesn't declare are written back unchanged.
	local values = table.copy(GG["MissionAPI"].SavedVariables)
	for key in pairs(GG["MissionAPI"].PersistentVariableKeys) do
		values[key] = GG["MissionAPI"].Variables[key]
	end
	return values
end

local function encodePersistentVariables()
	local values = collectPersistentVariables()
	-- The encoder would write an empty table as an array, but the save is an object.
	local json = next(values) ~= nil and Json.encode(values) or "{}"
	return VFS.ZlibCompress(json)
end

return {
	Encode = encodePersistentVariables,
}
