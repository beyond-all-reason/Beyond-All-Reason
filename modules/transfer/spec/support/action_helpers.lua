--- Seams the action specs share: the action files resolve Spring at call time.

local Helpers = {}

--- Runs fn with the global Spring swapped for a builder mock. The action files resolve
--- Spring at call time, so this is the seam; the mock gains what the actions send through.
---@param mock table
---@param fn fun(sent: string[])
function Helpers.withSpring(mock, fn)
	local sent = {}
	mock.Log = mock.Log or Spring.Log
	mock.SendLuaUIMsg = function(msg)
		sent[#sent + 1] = msg
	end
	mock.SendMessageToTeam = mock.SendMessageToTeam or function() end
	mock.SendMessageToPlayer = mock.SendMessageToPlayer or function() end
	mock.GetUnitHealth = mock.GetUnitHealth or function()
		return 100, 100
	end
	mock.AddUnitDamage = mock.AddUnitDamage or function() end
	local savedSpring, savedSendToUnsynced = Spring, _G.SendToUnsynced
	---@diagnostic disable-next-line: global-in-non-module
	_G.Spring = mock
	---@diagnostic disable-next-line: global-in-non-module
	_G.SendToUnsynced = _G.SendToUnsynced or function() end
	local ok, err = pcall(fn, sent)
	---@diagnostic disable-next-line: global-in-non-module
	_G.Spring, _G.SendToUnsynced = savedSpring, savedSendToUnsynced
	if not ok then
		error(err, 0)
	end
end

--- ValidateUnits reads UnitDefs by id; the mock builder keys its defs by name.
---@param mock table
---@return table byId
function Helpers.unitDefsById(mock)
	local byKey = {}
	for key, def in pairs(mock.GetUnitDefs() or {}) do
		byKey[key] = def
		if def.id then
			byKey[def.id] = def
		end
		if def.name then
			byKey[def.name] = def
		end
	end
	return byKey
end

return Helpers
