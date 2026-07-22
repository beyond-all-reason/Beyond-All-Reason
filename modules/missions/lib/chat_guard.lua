--- Who may drive mission chat commands. Pure — the gadget supplies the
--- Spring facts — so the policy specs under busted.
---
--- Missions are a dev/campaign surface: in multiplayer, any player can send
--- a synced chat action, so arming or reloading a mission must not be an
--- open verb. Singleplayer is always allowed; elsewhere cheats must be on.

local ChatGuard = {}

---@param isSinglePlayer boolean
---@param cheatsEnabled boolean
---@return boolean
function ChatGuard.IsAllowed(isSinglePlayer, cheatsEnabled)
	return isSinglePlayer == true or cheatsEnabled == true
end

return ChatGuard
