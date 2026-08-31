
---@param request MissionReloadRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if request.loader.Active() == nil then
		return false, "no active mission to reload"
	end
	return true
end)

---@param request MissionReloadRequest
---@return boolean loaded
Actions.RegisterExecute(function(request)
	return request.loader.Reload()
end)
