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

local myPlayerID = Spring.GetMyPlayerID()

function UnloadIfSpec()
	local _, _, spec, _, _, _, _, _ = GetPlayerInfo(myPlayerID)
	if ( spec == true ) then
		widgetHandler:RemoveWidget()
		return 
	end
	return 
end

function widget:Initialize()
	UnloadIfSpec()
end

function widget:PlayerChanged()
	UnloadIfSpec()
end

function widget:DefaultCommand()
	local count = GetSelectedUnitsCount()
	if count==0 or count>10 then return end --we aren't micro-ing spies here...
	
	local selectedUnittypes = GetSelectedUnitsSorted()
	for spyDefID in pairs(spies) do
		if selectedUnittypes[spyDefID] then
			for _,unitID in pairs(selectedUnittypes[spyDefID]) do
				if GetUnitStates(unitID).cloak then
					return CMD_MOVE
				end
			end
		end
	end
end
