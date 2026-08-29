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
