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

local CMD_MOVE = CMD.MOVE


function widget:DefaultCommand()
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
