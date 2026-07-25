--- Combat exception ledger (protected/stunned units); pure Lua so it specs
--- under busted. Fields are flat tables so hot callins read them directly.

local Guard = {}

---@class CombatGuard
---@field ["protected"] table<integer, boolean> flat set for hot-callin gates; quoted because "protected" is a LuaCATS keyword
---@field stunned table<integer, integer> unitID -> release frame
---@field Protect fun(unitID: integer)
---@field Unprotect fun(unitID: integer)
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

	---@param unitID integer
	guard.Protect = function(unitID)
		guard.protected[unitID] = true
	end

	---@param unitID integer
	guard.Unprotect = function(unitID)
		guard.protected[unitID] = nil
	end

	---@param unitID integer
	---@return boolean
	guard.IsProtected = function(unitID)
		return guard.protected[unitID] == true
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
