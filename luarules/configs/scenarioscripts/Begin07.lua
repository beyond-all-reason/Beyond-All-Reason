
if gadgetHandler:IsSyncedCode() then
    isSynced = true
else
    isSynced = false
end
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
			if gadget:UnitDestroyed(unitID) then
				
			end
        end
    end

	local objectiveUnits = {
		{name = 'armck', x = 164, y = 432, z = 2649, rot = 0, teamID = 0, queue = {
		  [1] = {cmdID = CMD.MOVE, params = {123, 456, 789}},
		  [2] = {cmdID = CMD.PATROL, params = {222, 333, 444}},
		  [3] = {cmdID = CMD.PATROL, params = {555, 666, 777}},
		}},}

		for k , unit in pairs(objectiveUnits) do
			local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
			for i = 1, #unit.queue do
				local order = unit.queue[i]
				Spring.GiveOrderToUnit(unitID, order.cmdID, order.params, CMD.OPT_SHIFT)
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

--[[mx1= 533, my1= 434, mz1= 2155 ; mx2= 1118, my2= 428, mz2= 2157; mx3= 1906, my3= 431, mz3= 1223]]--
    --[[
    local name = unitData.name
local ud = UnitDefNames[name]
if not (ud and ud.id) then
	Spring.Echo("Missing unit placement", name)
	return
end

    local commandsToGive = nil -- Give commands just after game start
    if unitData.commands then
	local commands = unitData.commands
	commandsToGive = commandsToGive or {}
	commandsToGive[#commandsToGive + 1] = {
		unitID = unitID,
		commands = commands,
	}
elseif unitData.patrolRoute then
	local patrolRoute = unitData.patrolRoute
	local patrolCommands = {
		[1] = {
			cmdID = CMD_RAW_MOVE,
			pos = patrolRoute[1]
		}
	}
	
	for i = 2, #patrolRoute do
		patrolCommands[#patrolCommands + 1] = {
			cmdID = CMD.PATROL,
			pos = patrolRoute[i],
			options = {"shift"}
		}
	end
	
	commandsToGive = commandsToGive or {}
	commandsToGive[#commandsToGive + 1] = {
		unitID = unitID,
		commands = patrolCommands,
	}
elseif unitData.selfPatrol then
	local vx = mapCenterX - x
	local vz = mapCenterZ - z
	local cx = x + vx*25/math.abs(vx)
	local cz = z + vz*25/math.abs(vz)
	
	local patrolCommands = {
		[1] = {
			cmdID = CMD.PATROL,
			pos = {cx, cz}
		}
	}
	
	commandsToGive = commandsToGive or {}
	commandsToGive[#commandsToGive + 1] = {
		unitID = unitID,
		commands = patrolCommands,
	}
end

if unitData.movestate then
	commandsToGive = commandsToGive or {}
	if commandsToGive[#commandsToGive] and commandsToGive[#commandsToGive].unitID == unitID then
		local cmd = commandsToGive[#commandsToGive].commands
		cmd[#cmd + 1] = {cmdID = CMD.MOVE_STATE, params = {unitData.movestate}, options = {"shift"}}
	else
		commandsToGive[#commandsToGive + 1] = {
			unitID = unitID,
			commands = {cmdID = CMD.MOVE_STATE, params = {unitData.movestate}, options = {"shift"}}
		}
	end
end]]--

--[[
    local function ProcessUnitCommand(unitID, command)
	if command.unitName then
		local ud = UnitDefNames[command.unitName]
		command.cmdID = ud and ud.id and -ud.id
		if not command.cmdID then
			return
		end
		if command.pos then
			command.pos[1], command.pos[2] = SanitizeBuildPositon(command.pos[1], command.pos[2], ud, command.facing or 0)
		else -- Must be a factory production command
			Spring.GiveOrderToUnit(unitID, command.cmdID, 0, command.options or 0)
			return
		end
	end
	
	local team = Spring.GetUnitTeam(unitID)
	
	if command.pos then
		local x, z = command.pos[1], command.pos[2]
		local y = CallAsTeam(team,
			function ()
				return Spring.GetGroundHeight(x, z)
			end
		)
		
		Spring.GiveOrderToUnit(unitID, command.cmdID, {x, y, z, command.facing or command.radius}, command.options or 0)
		return
	end
	
	if command.atPosition then
		local p = command.atPosition
		local units = Spring.GetUnitsInRectangle(p[1] - BUILD_RESOLUTION, p[2] - BUILD_RESOLUTION, p[1] + BUILD_RESOLUTION, p[2] + BUILD_RESOLUTION)
        if units and units[1] then
			Spring.GiveOrderToUnit(unitID, command.cmdID, units[1], command.options or 0)
		end
		return
	end
	
	local params = {}
	if command.params then
		for i = 1, #command.params do -- Somehow tables lose their order
			params[i] = command.params[i]
		end
	end
	Spring.GiveOrderToUnit(unitID, command.cmdID, params, command.options or 0)
end

local function GiveCommandsToUnit(unitID, commands)
	for i = 1, #commands do
		ProcessUnitCommand(unitID, commands[i])
	end
end
]]--