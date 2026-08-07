--- The build-delay registry: which builders are standing down, and until when.
---
--- Owned here because the engine asks construction whether a build step is
--- allowed, and an answer that lives in another module cannot be given
--- without that module being underneath this one. Transfer writes to it
--- through the module API; nothing else does.

local PolicyEvents = VFS.Include("modules/context/policy_events.lua")

local delayed = {} ---@type table<integer, integer> unitID -> expire frame

local Debuff = {}

---@param unitID integer
---@param seconds number
function Debuff.Apply(unitID, seconds)
	local startFrame = Spring.GetGameFrame()
	local expireFrame = startFrame + (seconds * Game.gameSpeed)
	delayed[unitID] = expireFrame
	PolicyEvents.NotifyBuildDelay(unitID, startFrame, expireFrame)
end

---@param unitID integer
---@return boolean
function Debuff.IsDelayed(unitID)
	return delayed[unitID] ~= nil
end

---Drop a builder's delay and say so. Returns whether there was one.
---@param unitID integer
---@return boolean released
function Debuff.Release(unitID)
	if delayed[unitID] == nil then
		return false
	end
	delayed[unitID] = nil
	PolicyEvents.NotifyBuildDelayEnd(unitID)
	return true
end

---Release every delay that has run out.
---@param frame integer
function Debuff.Expire(frame)
	for unitID, expireFrame in pairs(delayed) do
		if frame >= expireFrame then
			Debuff.Release(unitID)
		end
	end
end

return Debuff
