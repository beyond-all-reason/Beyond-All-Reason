--- Arm a mission.
---
--- The module's one effectful path for putting a mission on the board. The
--- chat action and the in-game panel both come through here, so the guard,
--- the name check and the transaction happen once each rather than once per
--- caller.
---
--- validate is pure: it answers whether this name is a mission this install
--- ships. WHO may ask is the channel's business — a synced chat action
--- arrives from any player, and the guard for that sits on the command.

local MISSIONS_DIR = "modules/missions/"

---@param request MissionLoadRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" or type(request.mission) ~= "string" or request.mission == "" then
		return false, "usage: /mission load <name>"
	end
	if #VFS.DirList(MISSIONS_DIR .. request.mission .. "/triggers/", "*.lua") == 0 then
		return false, "no mission named " .. request.mission .. " (nothing under " .. MISSIONS_DIR .. request.mission .. "/triggers/)"
	end
	return true
end)

---@param request MissionLoadRequest
---@return boolean loaded
Actions.RegisterExecute(function(request)
	-- The loader arrives in the request. An action file runs in the
	-- registrar's environment, not the gadget's, so GG here is not the GG the
	-- gadget wrote to — reaching for it finds nothing, whatever Initialize set.
	return request.loader.Load(request.mission)
end)
