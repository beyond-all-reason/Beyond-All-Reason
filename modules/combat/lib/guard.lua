
local Guard = {}

---@class CombatGuard
---@field ["protected"] table<integer, integer> unitID -> live protection count; truthy is the hot-callin gate. Quoted because "protected" is a LuaCATS keyword
---@field stunned table<integer, integer> unitID -> release frame
---@field Protect fun(unitID: integer): boolean became protected (the 0 -> 1 edge)
---@field Unprotect fun(unitID: integer): boolean became unprotected (the 1 -> 0 edge)
---@field IsProtected fun(unitID: integer): boolean
---@field HasProtected fun(): boolean
---@field Stun fun(unitID: integer, releaseFrame: integer)
---@field HasStunned fun(): boolean
---@field Tick fun(frame: integer): integer[] units due for release; cleared from the ledger
---@field UnitDestroyed fun(unitID: integer)

---@return CombatGuard
function Guard.New()
	local guard = {
		protected = {},
		stunned = {},
	}

	---A refcount, not a set: .Until makes overlapping lifetimes expressible,
	---so a release ends its own protection and no one else's.
	---@param unitID integer
	---@return boolean opened the 0 -> 1 edge, where the Spring-side effects apply
	guard.Protect = function(unitID)
		local count = (guard.protected[unitID] or 0) + 1
		guard.protected[unitID] = count
		return count == 1
	end

	---@param unitID integer
	---@return boolean closed the 1 -> 0 edge, where the Spring-side effects lift
	guard.Unprotect = function(unitID)
		local count = guard.protected[unitID]
		if count == nil then
			return false
		end
		if count > 1 then
			guard.protected[unitID] = count - 1
			return false
		end
		guard.protected[unitID] = nil
		return true
	end

	---@param unitID integer
	---@return boolean
	guard.IsProtected = function(unitID)
		return guard.protected[unitID] ~= nil
	end

	---@return boolean
	guard.HasProtected = function()
		return next(guard.protected) ~= nil
	end

	---A later Stun overwrites the release frame — last write wins.
	---@param unitID integer
	---@param releaseFrame integer
	guard.Stun = function(unitID, releaseFrame)
		guard.stunned[unitID] = releaseFrame
	end

	---@return boolean
	guard.HasStunned = function()
		return next(guard.stunned) ~= nil
	end

	---@param frame integer
	---@return integer[] released
	guard.Tick = function(frame)
		local released = {}
		for unitID, releaseFrame in pairs(guard.stunned) do
			if frame >= releaseFrame then
				released[#released + 1] = unitID
			end
		end
		for _, unitID in ipairs(released) do
			guard.stunned[unitID] = nil
		end
		return released
	end

	---@param unitID integer
	guard.UnitDestroyed = function(unitID)
		guard.protected[unitID] = nil
		guard.stunned[unitID] = nil
	end

	return guard
end

return Guard
