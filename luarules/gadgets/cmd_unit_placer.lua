local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Placer",
		desc = "Places real units for the terraform brush's UNITS tool, with stroke undo and redo",
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
--   $unit_place_undo$   /   $unit_place_redo$
-- Gated like the rest of the editor suite: cheats on, or the editor sandbox.

if not gadgetHandler:IsSyncedCode() then
	return
end

local PLACE_HEADER = "$unit_place$"
local UNDO_HEADER = "$unit_place_undo$"
local REDO_HEADER = "$unit_place_redo$"
local MAX_STROKES = 100
local FACING_OK = { [0] = true, [1] = true, [2] = true, [3] = true }

local strokes = {} -- stroke id -> { id, units = { { unitID, def, x, z, facing, team } } }
local undoStack = {} -- stroke ids, oldest first
local redoStack = {} -- strokes taken back, newest last

local function allowed()
	return Spring.IsCheatingEnabled() or tostring(Spring.GetModOptions().editor_sandbox or "") == "1"
end

local function create(def, x, z, facing, team)
	local unitDef = UnitDefNames[def]
	if not unitDef then
		return nil
	end
	local y = Spring.GetGroundHeight(x, z)
	return Spring.CreateUnit(unitDef.id, x, y, z, facing, team)
end

local function place(strokeId, team, body)
	local stroke = strokes[strokeId]
	if not stroke then
		stroke = { id = strokeId, units = {} }
		strokes[strokeId] = stroke
		undoStack[#undoStack + 1] = strokeId
		redoStack = {}
		if #undoStack > MAX_STROKES then
			strokes[table.remove(undoStack, 1)] = nil
		end
	end
	for def, xText, zText, facingText in body:gmatch("([%w_]+),(-?%d+%.?%d*),(-?%d+%.?%d*),(%d)") do
		local x, z, facing = tonumber(xText), tonumber(zText), tonumber(facingText)
		if x and z and FACING_OK[facing] then
			local unitID = create(def, x, z, facing, team)
			if unitID then
				stroke.units[#stroke.units + 1] =
					{ unitID = unitID, def = def, x = x, z = z, facing = facing, team = team }
			end
		end
	end
end

local function undo()
	local strokeId = table.remove(undoStack)
	local stroke = strokeId and strokes[strokeId]
	if not stroke then
		return
	end
	for _, unit in ipairs(stroke.units) do
		if unit.unitID and Spring.ValidUnitID(unit.unitID) then
			Spring.DestroyUnit(unit.unitID, false, true)
		end
		unit.unitID = nil
	end
	redoStack[#redoStack + 1] = strokeId
end

local function redo()
	local strokeId = table.remove(redoStack)
	local stroke = strokeId and strokes[strokeId]
	if not stroke then
		return
	end
	for _, unit in ipairs(stroke.units) do
		unit.unitID = create(unit.def, unit.x, unit.z, unit.facing, unit.team)
	end
	undoStack[#undoStack + 1] = strokeId
end

-- Nothing is returned: another gadget reading the same message is harmless (each checks its
-- own header), and the callin's type says it returns nothing.
function gadget:RecvLuaMsg(msg, playerID)
	local isPlace = msg:sub(1, #PLACE_HEADER) == PLACE_HEADER
	if not (isPlace or msg == UNDO_HEADER or msg == REDO_HEADER) then
		return
	end
	if not allowed() then
		Spring.Echo("[Unit Placer] Requires /cheat to be enabled")
		return
	end
	if msg == UNDO_HEADER then
		undo()
		return
	end
	if msg == REDO_HEADER then
		redo()
		return
	end
	local strokeId, team, body = msg:sub(#PLACE_HEADER + 1):match("^([%w_]+)|(%d+)|(.*)$")
	team = tonumber(team)
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
	place(strokeId, team, body)
end

function gadget:Initialize()
	GG.UnitPlacer = {
		--- For checks: how many strokes can be undone and redone.
		depth = function()
			return #undoStack, #redoStack
		end,
	}
end

function gadget:Shutdown()
	GG.UnitPlacer = nil
end
