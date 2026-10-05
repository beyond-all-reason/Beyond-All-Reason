---
--- Persistent variables are saved with campaign progress and written back out when the mission ends.
---

local base64 = VFS.Include("common/luaUtilities/base64.lua")

local function collectPersistentVariables()
	local values = {}
	for key in pairs(GG["MissionAPI"].PersistentVariables) do
		values[key] = GG["MissionAPI"].Variables[key]
	end
	return values
end

local function encodePersistentVariables()
	local values = collectPersistentVariables()
	-- The encoder would write an empty table as an array, but the save is an object.
	local json = next(values) == nil and "{}" or Json.encode(values)
	return base64.Encode(VFS.ZlibCompress(json))
end

return {
	Encode = encodePersistentVariables,
}
