
local ChatGuard = {}

---@param isSinglePlayer boolean
---@param cheatsEnabled boolean
---@return boolean
function ChatGuard.IsAllowed(isSinglePlayer, cheatsEnabled)
	return isSinglePlayer == true or cheatsEnabled == true
end

return ChatGuard
