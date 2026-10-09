-- Optional shared ATTACK input callbacks. No legacy receiver is expanded or
-- deferred implicitly: every receiver must explicitly support the batch.
local M = {}
local stats = { allow = 0, allowFallback = 0, notifications = 0, notifyFallback = 0 }
local reported = {}
stats.receivers = reported

function M.GetStats()
	return stats
end

local function fallback(kind, receiver)
	stats[kind .. "Fallback"] = stats[kind .. "Fallback"] + 1
	local info = receiver and (receiver.ghInfo or receiver.whInfo)
	local name = info and (info.basename or info.name) or "unit predicate"
	local key = kind .. ":" .. name
	if reported[key] then
		return
	end
	reported[key] = true
	if Spring and Spring.GetConfigInt and Spring.GetConfigInt("CommandBatchDiagnostics", 0) ~= 0 then
		Spring.Echo("[CommandBatch] legacy fallback " .. key)
	end
end

local function unitKey(id, def, team, player, synced, fromLua)
	return tostring(id)
		.. ":"
		.. tostring(def)
		.. ":"
		.. tostring(team)
		.. ":"
		.. tostring(player)
		.. ":"
		.. tostring(synced)
		.. ":"
		.. tostring(fromLua)
end

function M.NotificationDispatcher(getReceivers, afterNotify)
	local pending = setmetatable({}, { __mode = "k" })
	local function canNotify(unitID, unitDefID, teamID, commands, playerID, fromSynced, fromLua)
		for _, receiver in ipairs(getReceivers()) do
			if not receiver.UnitCommandBatch then
				fallback("notify", receiver)
				return false
			end
			if
				receiver.WantsUnitCommandBatch
				and not receiver:WantsUnitCommandBatch(
					unitID,
					unitDefID,
					teamID,
					commands,
					playerID,
					fromSynced,
					fromLua
				)
			then
				fallback("notify", receiver)
				return false
			end
		end
		return true
	end
	local function wants(unitID, unitDefID, teamID, commands, playerID, fromSynced, fromLua)
		if not canNotify(unitID, unitDefID, teamID, commands, playerID, fromSynced, fromLua) then
			return false
		end
		local batch = pending[commands]
		if not batch then
			batch = { units = {}, receivers = {} }
			pending[commands] = batch
		end
		local current = getReceivers()
		local snapshot = batch.receivers
		local changed = #snapshot ~= #current
		for i, receiver in ipairs(current) do
			if not snapshot[i] or snapshot[i][1] ~= receiver or snapshot[i][2] ~= receiver.UnitCommandBatch then
				changed = true
				break
			end
		end
		if changed then
			snapshot = {}
			for i, receiver in ipairs(current) do
				snapshot[i] = { receiver, receiver.UnitCommandBatch }
			end
			batch.receivers = snapshot
		end
		batch.units[unitKey(unitID, unitDefID, teamID, playerID, fromSynced, fromLua)] = snapshot
		return true
	end
	local function notify(unitID, unitDefID, teamID, commands, playerID, fromSynced, fromLua, ranges)
		local batch = pending[commands]
		local key = unitKey(unitID, unitDefID, teamID, playerID, fromSynced, fromLua)
		local snapshot = batch and batch.units[key]
		if not snapshot then
			return
		end
		batch.units[key] = nil
		stats.notifications = stats.notifications + 1
		for _, entry in ipairs(snapshot) do
			-- A removed receiver must not be called again by an already queued batch.
			for _, active in ipairs(getReceivers()) do
				if active == entry[1] then
					entry[2](entry[1], unitID, unitDefID, teamID, commands, playerID, fromSynced, fromLua, ranges)
					break
				end
			end
		end
		if afterNotify then
			afterNotify(unitID)
		end
	end
	return wants, notify, canNotify
end

-- Probe methods must be side-effect-free. Commit methods run only when every
-- receiver permits every input. Otherwise the original AllowCommand chain runs.
function M.AllowDispatcher(getReceivers, canNotify)
	return function(unitID, unitDefID, teamID, commands, playerID, fromSynced, fromLua)
		if not canNotify(unitID, unitDefID, teamID, commands, playerID, fromSynced, fromLua) then
			return nil
		end
		local receivers = getReceivers()
		for _, receiver in ipairs(receivers) do
			if
				not receiver.AllowCommandBatch
				or receiver:AllowCommandBatch(unitID, unitDefID, teamID, commands, playerID, fromSynced, fromLua)
					~= true
			then
				fallback("allow", receiver)
				return nil
			end
		end
		for _, receiver in ipairs(receivers) do
			if receiver.AllowCommandBatchCommit then
				receiver:AllowCommandBatchCommit(unitID, unitDefID, teamID, commands, playerID, fromSynced, fromLua)
			end
		end
		stats.allow = stats.allow + 1
		return true
	end
end

return M
