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

local spies  = {}

local spynames = {
	'armspy',
	'corspy',
	'legaspy',
}

for _, spyname in ipairs(spynames) do
	if UnitDefNames[spyname] then
		spies[UnitDefNames[spyname].id] = true
	end
end

local GetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local GetUnitStates = Spring.GetUnitStates
local GetSelectedUnitsCount = Spring.GetSelectedUnitsCount

local gameStarted, selectionChanged

local CMD_MOVE = CMD.MOVE

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
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
    if #spies == 0 then
	    widgetHandler:RemoveWidget()
	    return
    end
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

local spySelected = false
local selectedUnitsCount = GetSelectedUnitsCount()
function widget:SelectionChanged(sel)
	selectionChanged = true
end

local selChangedSec = 0
function widget:Update(dt)

	selChangedSec = selChangedSec + dt
	if selectionChanged and selChangedSec>0.1 then
		selChangedSec = 0
		selectionChanged = nil

		selectedUnitsCount = GetSelectedUnitsCount()

		spySelected = false
		if selectedUnitsCount > 0 and selectedUnitsCount <= 12 then  -- above a little amount we aren't micro-ing spies anymore...
			local selectedUnittypes = GetSelectedUnitsSorted()
			for spyDefID in pairs(spies) do
				if selectedUnittypes[spyDefID] then
					for _,unitID in pairs(selectedUnittypes[spyDefID]) do
						if select(5,GetUnitStates(unitID,false,true)) then	-- 5=cloak
							spySelected = true
							break
						end
					end
				end
				if spySelected then break end
			end
		end
	end
end

function widget:DefaultCommand()
	if spySelected then
		return CMD_MOVE
	end
end
