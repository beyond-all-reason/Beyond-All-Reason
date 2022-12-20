
if gadgetHandler:IsSyncedCode() then
    isSynced = true
else
    isSynced = false
end

	local objectiveUnits = {
		{name = 'armck', x = 164, y = 432, z = 2649, rot = 0, teamID = 0, queue = {
		[1] = {cmdID = CMD.MOVE, params = {123, 456, 789}},
		[2] = {cmdID = CMD.PATROL, params = {222, 333, 444}},
		[3] = {cmdID = CMD.PATROL, params = {555, 666, 777}},
		}},
		{name = 'armpw', x = 160, y = 432, z = 2649, rot = 0, teamID = 0, queue = {
		[1]	= {cmdID = CMD.PATROL, params = {px = 659, py = 435, pz = 2680}}
		}},
		{name = 'armrock', x = 156, y = 432, z = 2649, rot = 0, teamID = 0},
		{name = 'coradvsol', x = 82, y = 200, z = 3671, rot = 1, teamID = 1 },
		{name = 'armham', x = 152, y = 432, z = 2649, rot = 0, teamID = 0, px = 108, py = 426, pz = 2091},
	}

		for k , unit in pairs(objectiveUnits) do
			local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
			for i = 1, #unit.queue do
				local order = unit.queue[i]
				Spring.GiveOrderToUnit(unitID, order.cmdID, order.params, CMD.OPT_SHIFT)
			end
		end

--[[mx1= 533, my1= 434, mz1= 2155 ; mx2= 1118, my2= 428, mz2= 2157; mx3= 1906, my3= 431, mz3= 1223]]--
