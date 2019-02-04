function widget:GetInfo()
	return {
	name	= "Spy move/reclaim defaults",
	desc	= "prevents accidental spy decloak\nmakes move the default command for spies when cloaked",
	author	= "BD",
	date	= "-",
	license	= "WTFPL and horses",
	layer	= -math.huge,
	enabled	= true,
	}
end

local spies  = {
	[UnitDefNames.armspy.id] = true,
	[UnitDefNames.corspy.id] = true,
}

local GetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local GetUnitStates = Spring.GetUnitStates
local GetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local GetPlayerInfo = Spring.GetPlayerInfo

local CMD_MOVE = CMD.MOVE

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget(self)
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
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

local spySelected = false
local sec = 0
local lastUpdate = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > lastUpdate + 0.2 then
		lastUpdate = sec
		
		spySelected = false
		local count = GetSelectedUnitsCount()
		if count > 0 and count <= 12 then  -- above a little amount we aren't micro-ing spies anymore...
			local selectedUnittypes = GetSelectedUnitsSorted()
			for spyDefID in pairs(spies) do
				if selectedUnittypes[spyDefID] then
					for _,unitID in pairs(selectedUnittypes[spyDefID]) do
						if GetUnitStates(unitID).cloak then
							spySelected = true
						end
					end
				end
			end
		end
	end
end

function widget:DefaultCommand()
	if spySelected then
		return CMD_MOVE
	end
end
