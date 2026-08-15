--- Run the mission again from the top.
---
--- The other half of reload's split: reload preserves progress (the editor
--- nudging a number mid-run), restart is the fresh run — objectives cleared,
--- fired triggers unfired, the roster respawned.

---@param request MissionReloadRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if request.loader.Active() == nil then
		return false, "no active mission to restart"
	end
	return true
end)

---@param request MissionReloadRequest
---@return boolean loaded
Actions.RegisterExecute(function(request)
	return request.loader.Restart()
end)
