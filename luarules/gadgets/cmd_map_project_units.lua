function gadget:GetInfo()
	return {
		name = "Map Project Unit Loadout",
		desc = "Synced export and replay of the map's unit loadout for map projects",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Save side: cmd_map_project.lua requests an export; units are read HERE in
-- synced code because the unsynced view is LOS-limited — a player drafting a
-- mission would silently lose every enemy unit outside their own LOS.
-- Load side: the loadout streams in as begin/data/end messages and is applied
-- as an atomic replace inside the end handler: spawn the new units FIRST, then
-- destroy the pre-existing ones, so no team is ever observed with zero units
-- mid-swap (game-over logic watches for exactly that).

if not gadgetHandler:IsSyncedCode() then
	function gadget:RecvFromSynced(name, a)
		if name == "mpunits_save_begin" then
			if Script.LuaUI("mapproject_units_save_begin") then
				Script.LuaUI.mapproject_units_save_begin(a)
			end
		elseif name == "mpunits_save_data" then
			if Script.LuaUI("mapproject_units_save_data") then
				Script.LuaUI.mapproject_units_save_data(a)
			end
		elseif name == "mpunits_save_end" then
			if Script.LuaUI("mapproject_units_save_end") then
				Script.LuaUI.mapproject_units_save_end(a)
			end
		elseif name == "mpunits_save_denied" then
			if Script.LuaUI("mapproject_units_save_denied") then
				Script.LuaUI.mapproject_units_save_denied(a)
			end
		end
	end
	return
end

local EXPORT_HEADER = "$mpunits_export$"
local BEGIN_HEADER = "$mpunits_begin$"
local DATA_HEADER = "$mpunits_data$"
local END_HEADER = "$mpunits_end$"

local isSingleplayer = BAR.Utilities.Gametype.IsSinglePlayer()

local pending = nil -- entries accumulated between $mpunits_begin$ and $mpunits_end$
local pendingBad = 0 -- entries dropped at parse time (unknown unit def)
local ackCounter = 0 -- incremented per completed replace; mirrored to mpu_ack

-- Heading (-32768..32767) to CreateUnit facing 0..3 (same quantization as
-- unit_scenario_loadout.lua — the loadout format stays scenario-compatible).
local function rotToFacing(rotation)
	if rotation < 8192 and rotation > -8192 then
		return 0
	end
	if rotation > 8192 and rotation < 24576 then
		return 1
	end
	if rotation < -8192 and rotation > -24576 then
		return 3
	end
	return 2
end

local function exportAllUnits()
	local ids = Spring.GetAllUnits()
	local data = {}
	local format = string.format
	for i = 1, #ids do
		local uid = ids[i]
		local defID = Spring.GetUnitDefID(uid)
		local def = defID and UnitDefs[defID]
		local x, _, z = Spring.GetUnitPosition(uid)
		if def and x then
			data[#data + 1] = format(
				"%s %.1f %.1f %d %d %d",
				def.name,
				x,
				z,
				Spring.GetUnitHeading(uid) or 0,
				Spring.GetUnitTeam(uid) or 0,
				Spring.GetUnitNeutral(uid) and 1 or 0
			)
		end
	end
	SendToUnsynced("mpunits_save_begin", #data)
	local BATCH = 40
	for i = 1, #data, BATCH do
		SendToUnsynced("mpunits_save_data", table.concat(data, "|", i, math.min(i + BATCH - 1, #data)))
	end
	SendToUnsynced("mpunits_save_end", #data)
end

local function replaceAllUnits()
	local old = Spring.GetAllUnits()
	local gaia = Spring.GetGaiaTeamID()
	local spawned, failed, remapped = 0, pendingBad, 0
	local max, min = math.max, math.min
	for _, u in ipairs(pending) do
		local team = u.team
		local tid, _, isDead = Spring.GetTeamInfo(team, false)
		if not tid or isDead then
			-- Invalid or dead team in this session: keep the unit on the map
			-- under Gaia rather than dropping it.
			team = gaia
			remapped = remapped + 1
		end
		local x = max(0, min(Game.mapSizeX, u.x))
		local z = max(0, min(Game.mapSizeZ, u.z))
		local uid = Spring.CreateUnit(u.name, x, Spring.GetGroundHeight(x, z), z, rotToFacing(u.rot), team)
		if uid then
			spawned = spawned + 1
			Spring.GiveOrderToUnit(uid, CMD.STOP, {}, 0)
			if u.neutral then
				Spring.SetUnitNeutral(uid, true)
			end
		else
			failed = failed + 1
		end
	end
	local removed = 0
	for i = 1, #old do
		local uid = old[i]
		if Spring.ValidUnitID(uid) then
			Spring.DestroyUnit(uid, false, true)
			removed = removed + 1
		end
	end
	ackCounter = ackCounter + 1
	Spring.SetGameRulesParam("mpu_spawned", spawned)
	Spring.SetGameRulesParam("mpu_failed", failed)
	Spring.SetGameRulesParam("mpu_removed", removed)
	Spring.SetGameRulesParam("mpu_remapped", remapped)
	Spring.SetGameRulesParam("mpu_ack", ackCounter)
	Spring.Echo(
		string.format(
			"[Map Project Units] loadout applied: %d spawned, %d failed, %d pre-existing removed%s",
			spawned,
			failed,
			removed,
			remapped > 0 and (", " .. remapped .. " remapped to Gaia (team missing/dead)") or ""
		)
	)
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg == EXPORT_HEADER then
		-- Read-only, but it reveals every unit's position: refuse when it could
		-- serve as a maphack (multiplayer without cheats).
		if not (isSingleplayer or Spring.IsCheatingEnabled()) then
			SendToUnsynced("mpunits_save_denied", "needs a singleplayer session (or /cheat)")
			return true
		end
		exportAllUnits()
		return true
	end

	if msg == BEGIN_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Map Project Units] Requires /cheat to be enabled")
			return true
		end
		pending = {}
		pendingBad = 0
		return true
	end

	if msg:sub(1, #DATA_HEADER) == DATA_HEADER then
		if not Spring.IsCheatingEnabled() then
			return true
		end
		if not pending then
			return true
		end
		local payload = msg:sub(#DATA_HEADER + 1)
		for entry in payload:gmatch("[^|]+") do
			local name, x, z, rot, team, neutral = entry:match("^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+)$")
			x, z = tonumber(x), tonumber(z)
			if name and x and z and UnitDefNames[name] then
				pending[#pending + 1] = {
					name = name,
					x = x,
					z = z,
					rot = tonumber(rot) or 0,
					team = tonumber(team) or 0,
					neutral = neutral == "1",
				}
			else
				pendingBad = pendingBad + 1
				if name and not UnitDefNames[name] then
					Spring.Echo("[Map Project Units] unknown unit def, skipped: " .. name)
				end
			end
		end
		return true
	end

	if msg == END_HEADER then
		if not Spring.IsCheatingEnabled() then
			return true
		end
		if not pending then
			return true
		end
		replaceAllUnits()
		pending = nil
		pendingBad = 0
		return true
	end
end
