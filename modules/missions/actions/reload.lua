--- Re-arm the running mission.
---
--- Editing a trigger file changes nothing until the mission is armed again:
--- the loader swaps a whole staged engine in, so a reload is the smallest
--- unit of "try that edit". Same transaction as a fresh load.

---@return boolean allowed, string? reason
Actions.RegisterValidate(function()
	assert(GG ~= nil and GG.Missions ~= nil, "mission.reload called before the mission loader initialized")
	if GG.Missions.Active() == nil then
		return false, "no active mission to reload"
	end
	return true
end)

---@return boolean loaded
Actions.RegisterExecute(function()
	return GG.Missions.Reload()
end)
