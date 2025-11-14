local widget = widget ---@type Widget

function widget:GetInfo()
	return {
	name	= "Cloaked Commanders Default Move",
	desc	= "prevents accidental commander/decoy decloak\nmakes move the default command for commanders/decoys when cloaked",
	author	= "Catcow, BrainDamage",
	date	= "11/13/2025",
	license	= "GNU GPL, v2 or later",
	layer	= -999999,
	enabled	= true,
	}
end

-- Additional Info: Catcow wrote this file based on BrainDamage's file "unit_default_spy_move_cloaked.lua"
-- Also: Catcow does not know lua... help

-- Localized Spring API for performance
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetGameFrame = Spring.GetGameFrame


local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitStates = Spring.GetUnitStates

local idIsComOrDecoy = {}

local commanderAndDecoyNames = {
	'armcom',
	'armdecom',
	'corcom',
	'cordecom',
	'legcom',
	'legdecom',
}

for _, comName in ipairs(commanderAndDecoyNames) do
	if UnitDefNames[comName] then
		idIsComOrDecoy[UnitDefNames[comName].id] = true
	end
end

local gameStarted, selectionChanged

local CMD_MOVE = CMD.MOVE
local CMD_CLOAK = 37382

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or spGetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

local cloakedComSelected = false
local selectedUnitsCount = spGetSelectedUnitsCount()
function widget:SelectionChanged(sel)
	selectionChanged = true
end

local selChangedSec = 0
function widget:Update(dt)

	selChangedSec = selChangedSec + dt
	if selectionChanged and selChangedSec>0.1 then
		selChangedSec = 0
		selectionChanged = nil

		selectedUnitsCount = spGetSelectedUnitsCount()

		cloakedComSelected = false
		-- above a little amount we aren't micro-ing cloaked coms anymore...
		if selectedUnitsCount == 0 or selectedUnitsCount > 32 then return end

		local selectedUnitTypes = spGetSelectedUnitsSorted()
		for unitDefID, units in pairs(selectedUnitTypes) do
			if idIsComOrDecoy[unitDefID] then
				for _, unitID in pairs(units) do
					-- 5=cloak https://recoilengine.org/docs/lua-api/#Spring.GetUnitStates
					if select(5, spGetUnitStates(unitID,false,true)) then
						cloakedComSelected = true
						return
					end
				end
			end
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if (cmdID == CMD_CLOAK) and (idIsComOrDecoy[unitDefID]) and (teamID == spGetMyTeamID()) then
        selectionChanged = true
    end
end

function widget:DefaultCommand()
	if cloakedComSelected then
		return CMD_MOVE
	end
end
