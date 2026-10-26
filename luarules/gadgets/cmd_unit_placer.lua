local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Placer",
		desc = "Places, removes and moves real units for the terraform brush's UNITS tool, with stroke undo and redo",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- The terraform brush's UNITS tool (refactor plan, U6) places REAL units: a map maker lays
-- out a base or a battle to look at, light and screenshot. The mission editor places records
-- instead; both use the same library and placer on the LuaUI side.
--
-- Protocol (LuaUI -> here):
--   $unit_place$<stroke>|<team>|<def>,<x>,<z>,<facing>;<def>,<x>,<z>,<facing>;...
--       one placement gesture is one STROKE; a big one arrives in several messages with the
--       same stroke id, and undo takes the whole stroke back
--   $unit_remove$<stroke>|<id>,<id>,...
--       destroy units (no wreck); undo brings them back where they stood
--   $unit_transform$<stroke>|<id>,<x>,<z>,<facing>;...
--       move and turn units. A structure's footprint depends on its facing, so a unit is
--       destroyed and created again at its new spot (same team)
--   $unit_clearall$<stroke>
--       every unit on the map, all teams, as one remove stroke
--   $unit_place$<stroke>|m<n>|...   (team field "m" + a number)
--       MISSION units on mission team n: stand-ins for a mission, frozen in place (see freeze)
--   $unit_mission$<stroke>|<1|0>|ALL   or   ...|<1|0>|<id>,<id>,...
--       turn live units into mission units (1, each keeps its team as its mission team) or
--       mission units back into live ones (0), in place, as one stroke
--   $unit_place_undo$   /   $unit_place_redo$
-- Back (here -> LuaUI, through the unsynced half):
--   unit_placer_history(undoCount, redoCount) after every change
--   unit_placer_remap(oldID, newID) for every unit created again (undo, redo, transform), so
--       the widget's selection follows it
-- Gated like the rest of the editor suite: cheats on, or the editor sandbox.

if not gadgetHandler:IsSyncedCode() then
	-- Sync actions (a table lookup by name) rather than RecvFromSynced, which would see every
	-- SendToUnsynced of every synced gadget. Returning true stops the broadcast.
	local function onHistory(_, undoCount, redoCount)
		if Script.LuaUI("unit_placer_history") then
			Script.LuaUI.unit_placer_history(undoCount, redoCount)
		end
		return true
	end

	--- Remaps arrive batched as "old:new,old:new"; LuaUI hears them one pair at a time.
	local function onRemap(_, pairs_)
		if not Script.LuaUI("unit_placer_remap") then
			return true
		end
		for oldText, newText in tostring(pairs_ or ""):gmatch("(%d+):(%d+)") do
			Script.LuaUI.unit_placer_remap(tonumber(oldText), tonumber(newText))
		end
		return true
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("UnitPlacerHistory", onHistory)
		gadgetHandler:AddSyncAction("UnitPlacerRemap", onRemap)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("UnitPlacerHistory")
		gadgetHandler:RemoveSyncAction("UnitPlacerRemap")
	end
	return
end

local PLACE_HEADER = "$unit_place$"
local REMOVE_HEADER = "$unit_remove$"
local TRANSFORM_HEADER = "$unit_transform$"
local CLEARALL_HEADER = "$unit_clearall$"
local MISSION_HEADER = "$unit_mission$"
local UNDO_HEADER = "$unit_place_undo$"
local REDO_HEADER = "$unit_place_redo$"
local MAX_STROKES = 100
local FACING_OK = { [0] = true, [1] = true, [2] = true, [3] = true }
--- Id pairs per remap message to LuaUI.
local REMAP_BATCH = 64

local SendToUnsynced = SendToUnsynced

-- A stroke: { id, kind = "place" | "remove" | "transform", units = { ... } }
--   place / remove: { unitID, def, x, z, facing, team }
--   transform:      { unitID, def, team, before = { x, z, facing }, after = { x, z, facing } }
local undoStack = {} -- strokes, oldest first
local redoStack = {} -- strokes taken back, newest last

-- A mission editor PLAY session (or any Mission API mission) carries editor_sandbox=1
-- too, so that gate alone let editor tools into a running mission. They stay out of one.
local function isPlaySession()
	local modOptions = Spring.GetModOptions()
	return tostring(modOptions.mission_editor_play or "") == "1" or modOptions.missionoptions ~= nil
end

local function allowed()
	if isPlaySession() then
		return false
	end
	return Spring.IsCheatingEnabled() or tostring(Spring.GetModOptions().editor_sandbox or "") == "1"
end

local function sendHistory()
	SendToUnsynced("UnitPlacerHistory", #undoStack, #redoStack)
end

-- MISSION UNITS (Terraform Brush 1.18): the UNITS tool's MISSION mode places stand-ins for a
-- mission rather than units to play with: frozen in place (neutral, invulnerable, orders
-- refused, MoveCtrl holds them), and carrying a mission TEAM NUMBER that need not exist in
-- this session. They stand on that team when it exists (team colours for free), else on
-- Gaia. The number is a public rules param, "mission_team" (-1 once a unit is live again),
-- which the map project saves so the mission editor can take them as its loadout.
local missionUnits = {} -- unitID -> mission team number
local MISSION_PARAM = "mission_team"

local function realTeamFor(missionTeam)
	local tid, _, isDead = Spring.GetTeamInfo(missionTeam, false)
	if tid and not isDead then
		return missionTeam
	end
	return Spring.GetGaiaTeamID()
end

local function freeze(unitID, missionTeam)
	missionUnits[unitID] = missionTeam
	Spring.SetUnitRulesParam(unitID, MISSION_PARAM, missionTeam, { public = true })
	Spring.MoveCtrl.Enable(unitID)
	Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitArmored(unitID, true, 0)
end

local function thaw(unitID)
	missionUnits[unitID] = nil
	Spring.SetUnitRulesParam(unitID, MISSION_PARAM, -1, { public = true })
	Spring.MoveCtrl.Disable(unitID)
	Spring.SetUnitNeutral(unitID, false)
	Spring.SetUnitArmored(unitID, false)
	Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 2 }, 0)
	Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 1 }, 0)
end

-- the map project's units gadget restores saved mission units through the same freeze
GG.UnitPlacer = { freeze = freeze, realTeamFor = realTeamFor }

--- missionTeam nil = a live unit on `team`; a number = a mission unit (team is then derived)
local function create(def, x, z, facing, team, missionTeam)
	local unitDef = UnitDefNames[def]
	if not unitDef then
		return nil
	end
	if missionTeam then
		team = realTeamFor(missionTeam)
	end
	local y = Spring.GetGroundHeight(x, z)
	local unitID = Spring.CreateUnit(unitDef.id, x, y, z, facing, team)
	if unitID and missionTeam then
		freeze(unitID, missionTeam)
	end
	return unitID
end

local function destroy(unitID)
	if unitID and Spring.ValidUnitID(unitID) then
		Spring.DestroyUnit(unitID, false, true)
	end
end

--- What it takes to create a unit again: its type, where it stands, its facing, its team.
---@return table|nil { unitID, def, x, z, facing, team }
local function capture(unitID)
	if not Spring.ValidUnitID(unitID) then
		return nil
	end
	local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
	local x, _, z = Spring.GetUnitPosition(unitID)
	if not (unitDef and x) then
		return nil
	end
	return {
		unitID = unitID,
		def = unitDef.name,
		x = math.floor(x + 0.5),
		z = math.floor(z + 0.5),
		facing = (Spring.GetUnitBuildFacing(unitID) or 0) % 4,
		team = Spring.GetUnitTeam(unitID),
		missionTeam = missionUnits[unitID],
	}
end

-- Creating a unit again gives it a NEW id, and other strokes deeper in either stack may
-- still hold the old one (a transform after a place, a remove after a transform). So every
-- re-creation publishes old -> new across both stacks, and to LuaUI for the selection.
local function remap(mapping)
	if not next(mapping) then
		return
	end
	local function patch(stack)
		for i = 1, #stack do
			local units = stack[i].units
			for j = 1, #units do
				local newID = mapping[units[j].unitID]
				if newID then
					units[j].unitID = newID
				end
			end
		end
	end
	patch(undoStack)
	patch(redoStack)
	local parts = {}
	for oldID, newID in pairs(mapping) do
		parts[#parts + 1] = oldID .. ":" .. newID
		if #parts >= REMAP_BATCH then
			SendToUnsynced("UnitPlacerRemap", table.concat(parts, ","))
			parts = {}
		end
	end
	if #parts > 0 then
		SendToUnsynced("UnitPlacerRemap", table.concat(parts, ","))
	end
end

--- The stroke a message belongs to: the newest one when it has this id and kind (a big
--- gesture comes in several messages), else a new one, which drops the redo stack.
local function openStroke(strokeId, kind)
	local top = undoStack[#undoStack]
	if top and top.id == strokeId and top.kind == kind then
		return top
	end
	local stroke = { id = strokeId, kind = kind, units = {} }
	undoStack[#undoStack + 1] = stroke
	redoStack = {}
	if #undoStack > MAX_STROKES then
		table.remove(undoStack, 1)
	end
	return stroke
end

local function place(strokeId, team, body, missionTeam)
	local stroke = openStroke(strokeId, "place")
	for def, xText, zText, facingText in body:gmatch("([%w_]+),(-?%d+%.?%d*),(-?%d+%.?%d*),(%d)") do
		local x, z, facing = tonumber(xText), tonumber(zText), tonumber(facingText)
		if x and z and FACING_OK[facing] then
			local unitID = create(def, x, z, facing, team, missionTeam)
			if unitID then
				stroke.units[#stroke.units + 1] = {
					unitID = unitID,
					def = def,
					x = x,
					z = z,
					facing = facing,
					team = team,
					missionTeam = missionTeam,
				}
			end
		end
	end
end

--- Live units into mission units (on = true, each keeps its team as its mission team) or
--- back, in place: the ids stay, so nothing needs a remap.
local function setMission(strokeId, on, unitIDs)
	local stroke = openStroke(strokeId, "mission")
	for _, unitID in ipairs(unitIDs) do
		if Spring.ValidUnitID(unitID) then
			local was = missionUnits[unitID]
			if on and was == nil then
				local missionTeam = Spring.GetUnitTeam(unitID)
				freeze(unitID, missionTeam)
				stroke.units[#stroke.units + 1] = { unitID = unitID, on = true, missionTeam = missionTeam }
			elseif not on and was ~= nil then
				thaw(unitID)
				stroke.units[#stroke.units + 1] = { unitID = unitID, on = false, missionTeam = was }
			end
		end
	end
	if #stroke.units == 0 then
		table.remove(undoStack)
	end
	return #stroke.units
end

--- Undo (back = true) or redo a mission stroke.
local function replayMission(stroke, back)
	for _, unit in ipairs(stroke.units) do
		if Spring.ValidUnitID(unit.unitID) then
			if unit.on == back then
				thaw(unit.unitID)
			else
				freeze(unit.unitID, unit.missionTeam)
			end
		end
	end
end

--- Destroy units, recording each so undo can bring it back.
local function removeUnits(strokeId, unitIDs)
	local stroke = openStroke(strokeId, "remove")
	for _, unitID in ipairs(unitIDs) do
		local record = capture(unitID)
		if record then
			stroke.units[#stroke.units + 1] = record
			destroy(unitID)
		end
	end
end

local function transform(strokeId, body)
	local stroke = openStroke(strokeId, "transform")
	stroke.byID = stroke.byID or {}
	local mapping = {}
	for idText, xText, zText, facingText in body:gmatch("(%d+),(-?%d+%.?%d*),(-?%d+%.?%d*),(%d)") do
		local unitID, x, z, facing = tonumber(idText), tonumber(xText), tonumber(zText), tonumber(facingText)
		local record = unitID and x and z and FACING_OK[facing] and capture(unitID)
		if record then
			destroy(unitID)
			local newID = create(record.def, x, z, facing, record.team, record.missionTeam)
			if newID then
				-- The same unit moved twice in one stroke keeps its first "before".
				local entry = stroke.byID[unitID]
				if entry then
					stroke.byID[unitID] = nil
				else
					entry = {
						def = record.def,
						team = record.team,
						missionTeam = record.missionTeam,
						before = { x = record.x, z = record.z, facing = record.facing },
					}
					stroke.units[#stroke.units + 1] = entry
				end
				entry.unitID = newID
				entry.after = { x = x, z = z, facing = facing }
				stroke.byID[newID] = entry
				mapping[unitID] = newID
			end
		end
	end
	remap(mapping)
end

--- Create every unit of a stroke again at `which` ("before" / "after" for a transform, its
--- own spot otherwise), destroying the one standing there first.
local function recreate(stroke, which)
	local mapping = {}
	for _, unit in ipairs(stroke.units) do
		local spot = which and unit[which] or unit
		local oldID = unit.unitID
		destroy(oldID)
		unit.unitID = create(unit.def, spot.x, spot.z, spot.facing, unit.team, unit.missionTeam)
		if oldID and unit.unitID and oldID ~= unit.unitID then
			mapping[oldID] = unit.unitID
		end
	end
	stroke.byID = nil
	remap(mapping)
end

local function destroyStroke(stroke)
	for _, unit in ipairs(stroke.units) do
		destroy(unit.unitID)
	end
end

local function undo()
	local stroke = table.remove(undoStack)
	if not stroke then
		return
	end
	if stroke.kind == "place" then
		destroyStroke(stroke)
	elseif stroke.kind == "remove" then
		recreate(stroke)
	elseif stroke.kind == "mission" then
		replayMission(stroke, true)
	else
		recreate(stroke, "before")
	end
	redoStack[#redoStack + 1] = stroke
end

local function redo()
	local stroke = table.remove(redoStack)
	if not stroke then
		return
	end
	if stroke.kind == "place" then
		recreate(stroke)
	elseif stroke.kind == "remove" then
		destroyStroke(stroke)
	elseif stroke.kind == "mission" then
		replayMission(stroke, false)
	else
		recreate(stroke, "after")
	end
	undoStack[#undoStack + 1] = stroke
end

local modOptions = Spring.GetModOptions() or {}
if tostring(modOptions.editor_sandbox or "") == "1" or tostring(modOptions.mapeditor or "") == "1" then
	--- Mission units take no orders but the ones this gadget gives them.
	function gadget:AllowCommand(
		unitID,
		_unitDefID,
		_teamID,
		_cmdID,
		_cmdParams,
		_cmdOptions,
		_cmdTag,
		_playerID,
		fromSynced
	)
		return fromSynced or missionUnits[unitID] == nil
	end

	function gadget:UnitDestroyed(unitID)
		missionUnits[unitID] = nil
	end
end

local function startsWith(msg, header)
	return msg:sub(1, #header) == header
end

-- Nothing is returned: another gadget reading the same message is harmless (each checks its
-- own header), and the callin's type says it returns nothing.
function gadget:RecvLuaMsg(msg, playerID)
	local isPlace = startsWith(msg, PLACE_HEADER)
	local isRemove = startsWith(msg, REMOVE_HEADER)
	local isTransform = startsWith(msg, TRANSFORM_HEADER)
	local isClear = startsWith(msg, CLEARALL_HEADER)
	local isMission = startsWith(msg, MISSION_HEADER)
	if not (isPlace or isRemove or isTransform or isClear or isMission or msg == UNDO_HEADER or msg == REDO_HEADER) then
		return
	end
	if not allowed() then
		Spring.Echo("[Unit Placer] Requires /cheat to be enabled")
		return
	end
	if msg == UNDO_HEADER then
		undo()
	elseif msg == REDO_HEADER then
		redo()
	elseif isPlace then
		local strokeId, teamText, body = msg:sub(#PLACE_HEADER + 1):match("^([%w_%.]+)|(m?%d+)|(.*)$")
		local missionTeam = teamText and teamText:sub(1, 1) == "m" and tonumber(teamText:sub(2)) or nil
		local team = missionTeam and realTeamFor(missionTeam) or tonumber(teamText)
		if
			not (
				strokeId
				and team
				and Spring.GetTeamInfo(team --[[@as TeamID]], false)
			)
		then
			Spring.Echo("[Unit Placer] bad place message")
			return
		end
		place(strokeId, team, body, missionTeam)
	elseif isRemove then
		local strokeId, body = msg:sub(#REMOVE_HEADER + 1):match("^([%w_%.]+)|(.*)$")
		if not strokeId then
			Spring.Echo("[Unit Placer] bad remove message")
			return
		end
		local ids = {}
		for idText in body:gmatch("%d+") do
			ids[#ids + 1] = tonumber(idText)
		end
		if #ids == 0 then
			return
		end
		removeUnits(strokeId, ids)
	elseif isTransform then
		local strokeId, body = msg:sub(#TRANSFORM_HEADER + 1):match("^([%w_%.]+)|(.*)$")
		if not strokeId then
			Spring.Echo("[Unit Placer] bad transform message")
			return
		end
		transform(strokeId, body)
	elseif isMission then
		local strokeId, onText, body = msg:sub(#MISSION_HEADER + 1):match("^([%w_%.]+)|([01])|(.*)$")
		if not strokeId then
			Spring.Echo("[Unit Placer] bad mission message")
			return
		end
		local ids = {}
		if body == "ALL" then
			ids = Spring.GetAllUnits() or {}
		else
			for idText in body:gmatch("%d+") do
				ids[#ids + 1] = tonumber(idText)
			end
		end
		local n = setMission(strokeId, onText == "1", ids)
		Spring.Echo(
			string.format("[Unit Placer] %d unit(s) made %s", n, (onText == "1") and "mission units" or "live units")
		)
	else
		local strokeId = msg:sub(#CLEARALL_HEADER + 1):match("^([%w_%.]+)")
		local all = Spring.GetAllUnits() or {}
		if #all == 0 then
			return
		end
		removeUnits(strokeId or ("clear" .. Spring.GetGameFrame()), all)
	end
	sendHistory()
end
