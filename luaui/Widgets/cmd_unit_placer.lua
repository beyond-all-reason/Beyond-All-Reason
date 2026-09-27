local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Placer",
		desc = "The terraform brush's UNITS tool: pick from the unit library, place real units, undo by stroke",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false, -- the terraform suite turns it on; it must never load in a normal game
	}
end

-- The terraform brush's UNITS tool (refactor plan, U6). The same unit library and the same
-- placer as the mission editor (luaui/RmlWidgets/gui_unit_library, luaui/Include/unit_placer);
-- what differs is where a placement goes: here it becomes REAL units, through the Unit Placer
-- gadget, which keeps every placement gesture as one stroke to undo and redo.
--
-- Tool contract, as the suite's other tools: WG.UnitPlacerTool.activate / deactivate /
-- isActive. Activating opens the library; a pick arms the placer; a blueprint arms it as a
-- group. While active: T cycles the team units are placed for, Ctrl+Z / Ctrl+Y undo and redo
-- whole strokes (with the pointer over the map), and the placer's own keys (R, Tab).

local Placer = VFS.Include("luaui/Include/unit_placer/placer.lua")
local Cycle = VFS.Include("luaui/Include/unit_placer/cycle.lua")

local PLACE_HEADER = "$unit_place$"
local UNDO_HEADER = "$unit_place_undo$"
local REDO_HEADER = "$unit_place_redo$"
--- Units per message: a 40x40 grid is 1600 units, and one message carrying them all would
--- be a very long string for one frame.
local BATCH = 40
local KEY_T, KEY_Y, KEY_Z = 116, 121, 122

local active = false
local team = nil
local strokeCount = 0
-- Built in widget:Initialize, before any callin that reads it.
local placer ---@type table

local function teams()
	local out = {}
	for _, teamID in ipairs(Spring.GetTeamList() or {}) do
		out[#out + 1] = teamID
	end
	table.sort(out)
	return out
end

local function currentTeam()
	if team == nil then
		team = Spring.GetMyTeamID()
	end
	return team
end

local function worldPositionUnderMouse()
	local mx, my = Spring.GetMouseState()
	local kind, coords = Spring.TraceScreenRay(mx, my, true)
	if kind ~= "ground" or not coords then
		return nil
	end
	return coords[1], coords[3]
end

local function overUi()
	-- Over the unit library (or any RmlUi element the pointer is on), the keys are not ours.
	if WG.UnitLibrary and WG.UnitLibrary.contains then
		local mx, my = Spring.GetMouseState()
		local _, vsy = Spring.GetViewGeometry()
		if WG.UnitLibrary.contains(mx, vsy - my) then
			return true
		end
	end
	return false
end

--- Send a placement: one stroke, in batches.
local function send(result)
	strokeCount = strokeCount + 1
	local strokeId = string.format("s%d_%d", Spring.GetGameFrame(), strokeCount)
	local entries = {}
	local function flush()
		if #entries > 0 then
			Spring.SendLuaRulesMsg(
				PLACE_HEADER .. strokeId .. "|" .. tostring(result.team) .. "|" .. table.concat(entries, ";")
			)
			entries = {}
		end
	end
	if result.group then
		for _, spot in ipairs(result.units or {}) do
			entries[#entries + 1] = string.format("%s,%d,%d,%d", spot.unitDefName, spot.x, spot.z, spot.facing or 0)
			if #entries >= BATCH then
				flush()
			end
		end
	else
		for _, spot in ipairs(result.spots or {}) do
			entries[#entries + 1] = string.format("%s,%d,%d,%d", result.unitDefName, spot.x, spot.z, spot.facing or 0)
			if #entries >= BATCH then
				flush()
			end
		end
	end
	flush()
	return strokeId
end

---@type table?
local lastPick -- { kind = "unit" | "blueprint", value, mode, cycle }

--- Arm with the last pick again (a team change, the next type of a cycle). The shape and the
--- facing the keys left are kept.
local function rearm()
	if not (active and lastPick) then
		return
	end
	if lastPick.kind == "unit" then
		local live = placer.spec()
		if live and not live.group then
			lastPick.mode = live.mode
			lastPick.facing = live.facing
		end
		placer.arm({
			unitDefName = lastPick.value,
			team = currentTeam(),
			mode = lastPick.mode or "GRID",
			facing = lastPick.facing,
		})
	else
		placer.armGroup(lastPick.value.units, { team = currentTeam() })
	end
end

local function openLibrary()
	if not (WG.UnitLibrary and WG.UnitLibrary.open) then
		Spring.Echo("[Unit Placer] the unit library is not loaded (Unit Library UI)")
		return false
	end
	return WG.UnitLibrary.open({
		title = "TERRAFORM BRUSH",
		-- Several picked (Shift+click): each drop moves on to the next type (PtaQ's N2).
		onPick = function(unitDefName, set)
			local mode = placer.spec() and placer.spec().mode ~= "GROUP" and placer.spec().mode or "SINGLE"
			local names = set and set.names or { unitDefName }
			local cycle = #names > 1 and Cycle.new(names, set.mode) or nil
			lastPick = { kind = "unit", value = cycle and cycle.current() or unitDefName, mode = mode, cycle = cycle }
			rearm()
		end,
		onPickBlueprint = function(blueprint)
			lastPick = { kind = "blueprint", value = blueprint }
			rearm()
		end,
	})
end

local function activate()
	active = true
	openLibrary()
end

local function deactivate()
	active = false
	placer.disarm()
	if WG.UnitLibrary and WG.UnitLibrary.owner and WG.UnitLibrary.owner() == "TERRAFORM BRUSH" then
		WG.UnitLibrary.close()
	end
end

local function cycleTeam()
	local list = teams()
	local now = currentTeam()
	local nextTeam = list[1]
	for index, teamID in ipairs(list) do
		if teamID == now then
			nextTeam = list[index % #list + 1]
		end
	end
	team = nextTeam
	rearm()
	return team
end

function widget:Initialize()
	placer = Placer.new({
		owner = "unit_placer_tool",
		-- Stays armed after a placement: laying out a base is many drags of the same thing.
		sticky = true,
		onPlaced = function(result)
			send(result)
			local pick = lastPick
			if pick and pick.kind == "unit" and pick.cycle and pick.cycle.cycles() then
				pick.value = pick.cycle.advance()
				rearm()
			end
		end,
		onCancelled = function()
			lastPick = nil
			if WG.UnitLibrary and WG.UnitLibrary.clearPicks and WG.UnitLibrary.owner() == "TERRAFORM BRUSH" then
				WG.UnitLibrary.clearPicks()
			end
		end,
	})
	WG.UnitPlacerTool = {
		activate = activate,
		deactivate = deactivate,
		isActive = function()
			return active
		end,
		openLibrary = openLibrary,
		undo = function()
			Spring.SendLuaRulesMsg(UNDO_HEADER)
		end,
		redo = function()
			Spring.SendLuaRulesMsg(REDO_HEADER)
		end,
		cycleTeam = cycleTeam,
		team = currentTeam,
		--- For the harness: the placer, and a drop at a world point as a click would.
		placer = function()
			return placer
		end,
		--- The unit type armed now (a cycle moves it on after each drop).
		pickedType = function()
			return lastPick and lastPick.kind == "unit" and lastPick.value or nil
		end,
		placeAt = function(x1, z1, x2, z2)
			if not placer.armed() then
				return false
			end
			placer.mousePress(x1, z1, 1)
			placer.mouseMove(x2 or x1, z2 or z1)
			return placer.mouseRelease()
		end,
	}
end

function widget:Shutdown()
	placer.shutdown()
	WG.UnitPlacerTool = nil
end

function widget:MousePress(mx, my, button)
	if not (active and placer.armed()) then
		return false
	end
	local x, z = worldPositionUnderMouse()
	if button == 1 and not x then
		return false
	end
	return placer.mousePress(x, z, button)
end

function widget:MouseMove()
	if not (active and placer.armed()) then
		return false
	end
	local x, z = worldPositionUnderMouse()
	return placer.mouseMove(x, z)
end

function widget:MouseRelease()
	if not (active and placer.armed()) then
		return false
	end
	return placer.mouseRelease()
end

function widget:KeyPress(key, mods)
	if not active or overUi() then
		return false
	end
	mods = mods or {}
	if mods.ctrl and key == KEY_Z and not mods.shift then
		WG.UnitPlacerTool.undo()
		return true
	end
	if mods.ctrl and (key == KEY_Y or (key == KEY_Z and mods.shift)) then
		WG.UnitPlacerTool.redo()
		return true
	end
	if key == KEY_T and not mods.ctrl then
		Spring.Echo("[Unit Placer] placing for team " .. tostring(cycleTeam()))
		return true
	end
	if placer.armed() then
		return placer.keyPress(key, mods)
	end
	return false
end

function widget:Update()
	if active and placer.armed() then
		local x, z = worldPositionUnderMouse()
		placer.update(x, z)
	end
end

function widget:DrawWorld()
	if active and placer.armed() then
		placer.drawWorld()
	end
end
