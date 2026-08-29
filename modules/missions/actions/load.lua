
local MISSIONS_DIR = "modules/missions/"

---@class MissionLoaderApi
---@field Load fun(mission: string): boolean
---@field Reload fun(): boolean
---@field Active fun(): string|nil

---@class MissionLoadRequest
---@field mission string the directory name under modules/missions/
---@field loader MissionLoaderApi

---@class MissionReloadRequest
---@field loader MissionLoaderApi

---@param request MissionLoadRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" or type(request.mission) ~= "string" or request.mission == "" then
		return false, "usage: /mission load <name>"
	end
	if #VFS.DirList(MISSIONS_DIR .. request.mission .. "/triggers/", "*.lua") == 0 then
		return false,
			"no mission named "
				.. request.mission
				.. " (nothing under "
				.. MISSIONS_DIR
				.. request.mission
				.. "/triggers/)"
	end
	return true
end)

---@param request MissionLoadRequest
---@return boolean loaded
Actions.RegisterExecute(function(request)
	-- An action file runs in the registrar's environment, not the gadget's, so GG
	-- here is not the GG the gadget wrote to; the loader must arrive in the request.
	return request.loader.Load(request.mission)
end)
