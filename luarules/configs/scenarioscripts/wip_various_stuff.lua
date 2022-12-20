local function GetUnitSpawnHeight(unit)
    if unit.y then
      return unit.y
    end
    return Spring.GetGroundHeight(unit.x, unit.y)
  end -- defining height with unit.y Variable 
--ships have y=0
    if is.ship or is.aircraft then
    return unit.y
     else
        return GetGroundHeight(unit.x, unit.z)
    end
-- to use declareted unit.y for ships and aircrafts only that need it to be on land/water or in air

local px, py, pz
local patrolPos = {}
local objectiveUnits = {
    {name = 'armck', x = 164, y = 432, z = 2649, rot = 0, teamID = 0, px = 2183, py = 432, pz = 484},
    {name = 'armpw', x = 160, y = 432, z = 2649, rot = 0, teamID = 0, px = 659, py = 435, pz = 2680},
    {name = 'armrock', x = 156, y = 432, z = 2649, rot = 0, teamID = 0},
	{name = 'coradvsol', x = 82, y = 200, z = 3671, rot = 1, teamID = 1 },
    {name = 'armham', x = 152, y = 432, z = 2649, rot = 0, teamID = 0, px = 108, py = 426, pz = 2091},
}
local triggerUnits = {
	{name = 'armcom', x = 4091, y = 202, z = 5, rot = 3, teamID = 0, px =3391, py = 198, pz = 619}
}
    for k , unit in pairs(objectiveUnits) do
        if UnitDefNames[unit.name] then
				patrolPos = {unit["px"], unit["py"], unit["pz"]}
        local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
		   if unit["px"] then
				Spring.GiveOrderToUnit(unitID, CMD.PATROL, patrolPos, 0)
		   else
			Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
            end
			--[[if gadget:UnitDestroyed(unitID) then
				
			end]]--
        end
    end


    local objectiveUnits = {
			{name = 'armck', x = 164, y = 432, z = 2649, rot = 0, teamID = 0, patrol = {
			  [1] = {2183, 432, 484},
			  [2] = {1234, 567, 890},
			  [3] = {1357, 555, 777},
			}},
			{name = 'armpw', x = 160, y = 432, z = 2649, rot = 0, teamID = 0, patrol = { [1] = {659, 435, 2680}}},
			{name = 'armrock', x = 156, y = 432, z = 2649, rot = 0, teamID = 0, patrol = {} }, -- empty table
			{name = 'armham', x = 152, y = 432, z = 2649, rot = 0, teamID = 0, patrol = { [1] = {108, 426, 2091}}},
		}

		for k , unit in pairs(objectiveUnits) do
			local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
			for i = 1, #unit.patrol do
				Spring.GiveOrderToUnit(unitID, CMD.PATROL, unit.patrol[i], CMD.OPT_SHIFT)
			end
		end
