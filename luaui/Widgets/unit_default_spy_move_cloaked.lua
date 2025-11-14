local widget = widget ---@type Widget

function widget:GetInfo()
	return {
	name	= "Spy move/reclaim defaults",
	desc	= "prevents accidental spy decloak\nmakes move the default command for spies when cloaked",
	author	= "BrainDamage",
	date	= "-",
	license	= "WTFPL and horses",
	layer	= -999999,
	enabled	= true,
	}
end


-- Localized Spring API for performance
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetGameFrame = Spring.GetGameFrame

local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitStates = Spring.GetUnitStates

local idIsSpy = {}

local spyNames = {
	'armspy',
	'corspy',
	'legaspy',
}

for _, spyName in ipairs(spyNames) do
	if UnitDefNames[spyName] then
		idIsSpy[UnitDefNames[spyName].id] = true
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

local cloakedSpySelected = false
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

		cloakedSpySelected = false
		-- above a little amount we aren't micro-ing spies anymore...
		if selectedUnitsCount == 0 or selectedUnitsCount > 12 then return end

		local selectedUnitTypes = spGetSelectedUnitsSorted()
		for unitDefID, units in pairs(selectedUnitTypes) do
			if idIsSpy[unitDefID] then
				for _, unitID in pairs(units) do
					-- 5=cloak https://recoilengine.org/docs/lua-api/#Spring.GetUnitStates
					if select(5, spGetUnitStates(unitID,false,true)) then
						cloakedSpySelected = true
						return
					end
				end
			end
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if (cmdID == CMD_CLOAK) and (idIsSpy[unitDefID]) and (teamID == spGetMyTeamID()) then
        selectionChanged = true
    end
end

function widget:DefaultCommand()
	if cloakedSpySelected then
		return CMD_MOVE
	end
end
