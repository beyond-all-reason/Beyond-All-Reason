
local BuildEvents = VFS.Include("modules/construction/lib/build_events.lua")

local delayed = {} ---@type table<integer, integer> unitID -> expire frame

local Debuff = {}

---@param unitID integer
---@param seconds number
function Debuff.Apply(unitID, seconds)
	local startFrame = Spring.GetGameFrame()
	local expireFrame = startFrame + (seconds * Game.gameSpeed)
	delayed[unitID] = expireFrame
	BuildEvents.NotifyBuildDelay(unitID, startFrame, expireFrame)
end

---@param unitID integer
---@return boolean
function Debuff.IsDelayed(unitID)
	return delayed[unitID] ~= nil
end

---@param unitID integer
---@return boolean released
function Debuff.Release(unitID)
	if delayed[unitID] == nil then
		return false
	end
	delayed[unitID] = nil
	BuildEvents.NotifyBuildDelayEnd(unitID)
	return true
end

---@param frame integer
function Debuff.Expire(frame)
	for unitID, expireFrame in pairs(delayed) do
		if frame >= expireFrame then
			Debuff.Release(unitID)
		end
	end
end

return Debuff
