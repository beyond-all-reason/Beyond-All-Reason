function widget:GetInfo()
	return {
		name      = "Show Builder Queue",	-- old name: Show Build
		desc      = "Shows buildings about to be built",
		author    = "WarXperiment",
		date      = "February 15, 2010",
		license   = "GNU GPL, v2 or later",
        version   = "5",
        layer     = 55,
		enabled   = false,  --  loaded by default?
    }
end

local showForCreatedUnits = false		-- keep drawing unitshape for building when it has a nanoframe but isnt finished

--Changelog
-- before v2 developed outside of BA by WarXperiment
-- v2 [teh]decay - fixed crash: Error in DrawWorld(): [string "LuaUI/Widgets/unit_showbuild.lua"]:82: bad argument #1 to 'GetTeamColor' (number expected, got no value)
-- v3 [teh]decay - updated for spring 98 engine -- project page on github: https://github.com/jamerlan/unit_showbuild
-- v4 Floris - lots of performance increases
-- v5 Floris - cleanup, polishing and fixes

local command = {}
local commandOrdered = {}
local commandCreatedUnits = {}
local commandCreatedUnitsIDs = {}
local builders = {}
local myPlayerID = Spring.GetMyPlayerID()
local maxDisplayed = 150

local builderUnitDefs = {}
for udefID,def in ipairs(UnitDefs) do
	if def.isBuilder and not def.isFactory and def.buildOptions[1] then
		local buildOptions = {}
		for _,unit in ipairs(def.buildOptions) do
			buildOptions[unit] = true
		end
		builderUnitDefs[udefID] = buildOptions
	end
end

function updateBuilders()
	for unitID, _ in pairs(builders) do
		checkBuilder(unitID)
	end
end

function addBuilders()
	command = {}
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local uDefID = Spring.GetUnitDefID(unitID)
		if builderUnitDefs[uDefID] then
			builders[unitID] = true
			checkBuilder(unitID)
		end
	end
end

function widget:Initialize()
	if Spring.GetGameFrame() > 0 then
		addBuilders()
	end
end

function widget:PlayerChanged(playerID)
	if playerID == myPlayerID and Spring.GetGameFrame() > 0 and Spring.GetSpectatingState() then
		addBuilders()
		updateBuilders()
	end
end

function clearBuilderCommands(unitID)
	if commandOrdered[unitID] then
		for id, _ in pairs(commandOrdered[unitID]) do
			if command[id] and command[id][unitID] then
				command[id][unitID] = nil
				command[id].builders = command[id].builders - 1
				if command[id].builders == 0 then
					command[id] = nil
				end
			end
		end
		commandOrdered[unitID] = nil
	end
end

local gameFrame = Spring.GetGameFrame()
function widget:GameFrame(gf)
	gameFrame = gf
end

local newUnitCommands = {}
function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, _, _)
	if builderUnitDefs[unitDefID] then
		newUnitCommands[unitID] = os.clock() + 0.05
	end
end

local sec = 0
local lastUpdate = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > lastUpdate + 0.1 then
		lastUpdate = sec

		-- process newly given commands (not done in widgetUnitCommand() because with huge build queue it eats memory and can crash lua)
		local clock =  os.clock()
		for unitID, cmdClock in pairs(newUnitCommands) do
			if clock > cmdClock then
				checkBuilder(unitID)
				newUnitCommands[unitID] = nil
			end
		end
	end
end

function checkBuilder(unitID)
	clearBuilderCommands(unitID)
	local queue = Spring.GetCommandQueue(unitID, 200)
	if(queue and #queue > 0) then
		for _, cmd in ipairs(queue) do
			if ( cmd.id < 0 ) then
				local myCmd = {
					id = math.abs(cmd.id),
					teamid = Spring.GetUnitTeam(unitID),
					params = cmd.params
				}
				local y = cmd.params[2]
				if UnitDefs[math.abs(cmd.id)].minWaterDepth < 0 then	-- AI bots queue very high y pos so this corrects that
					y = Spring.GetGroundHeight(cmd.params[1],cmd.params[3])
				else
					y = - UnitDefs[math.abs(cmd.id)].waterline
				end
				myCmd.params[2] = y
				local id = Spring.GetUnitTeam(unitID)..'_'..math.abs(cmd.id)..'_'..cmd.params[1]..'_'..myCmd.params[2]..'_'..cmd.params[3]
				if showForCreatedUnits or commandCreatedUnits[id] == nil then
					if command[id] == nil then
						command[id] = {id = myCmd, builders = 0}
					end
					command[id][unitID] = true
					command[id].builders = command[id].builders + 1
					if commandOrdered[unitID] == nil then
						commandOrdered[unitID] = {}
					end
					commandOrdered[unitID][id] = true
				end
			end
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if commandCreatedUnitsIDs[unitID] then
		commandCreatedUnits[commandCreatedUnitsIDs[unitID]] = nil
		commandCreatedUnitsIDs[unitID] = nil
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local x,y,z = Spring.GetUnitPosition(unitID)
	if UnitDefs[unitDefID].minWaterDepth < 0 then
		y = Spring.GetGroundHeight(x,z)
	else
		y = - UnitDefs[unitDefID].waterline
	end
	if command[unitTeam..'_'..unitDefID..'_'..x..'_'..y..'_'..z] then
		command[unitTeam..'_'..unitDefID..'_'..x..'_'..y..'_'..z] = nil
		commandCreatedUnitsIDs[unitID] = unitTeam..'_'..unitDefID..'_'..x..'_'..y..'_'..z
		commandCreatedUnits[unitTeam..'_'..unitDefID..'_'..x..'_'..y..'_'..z] = true
	end
	if builderUnitDefs[unitDefID] then
		builders[unitID] = true
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, builderID)
	if builders[unitID] then
		builders[unitID] = nil
		newUnitCommands[unitID] = nil
		clearBuilderCommands(unitID)
	end
	if commandCreatedUnitsIDs[unitID] then
		commandCreatedUnits[commandCreatedUnitsIDs[unitID]] = nil
	end
end


function widget:DrawWorld()
	if Spring.IsGUIHidden() then return end

	gl.DepthTest(true)
	local commandVisible = 0
	for _, units in pairs(command) do
		local myCmd = units.id
		local params = myCmd.params

		local x, y, z = params[1], params[2], params[3]
		local degrees = params[4] ~= nil and params[4] * 90  or 0 -- mex command doesnt supply param 4
		if Spring.IsAABBInView(x-1,y-1,z-1,x+1,y+1,z+1) then
			gl.PushMatrix()
				gl.LoadIdentity()
				gl.Translate( x, y, z )
				gl.Rotate( degrees, 0, 1.0, 0 )
				gl.UnitShape(myCmd.id, myCmd.teamid, false, false, false)
			gl.PopMatrix()
			commandVisible = commandVisible + 1
			if commandVisible > maxDisplayed then
				break
			end
		end
	end
	gl.DepthTest(false)
	gl.Color(1, 1, 1, 1)
end

