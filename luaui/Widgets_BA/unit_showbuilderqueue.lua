function widget:GetInfo()
	return {
		name      = "Show Builder Queue",	-- old name: Show Build
		desc      = "Shows buildings about to be built",
		author    = "WarXperiment",
		date      = "February 15, 2010",
		license   = "GNU GPL, v2 or later",
        version   = "5",
        layer     = -4,
		enabled   = false,  --  loaded by default?
    }
end

local showForCreatedUnits = true		-- keep drawing unitshape for building when it has a nanoframe but isnt finished

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
local buildersOrdered = {{},{},{},{},{},{},{},{},{},{}}
local myPlayerID = Spring.GetMyPlayerID()
local _, _, isPaused = Spring.GetGameSpeed()

local glPushMatrix		= gl.PushMatrix
local glPopMatrix		= gl.PopMatrix
local glTranslate		= gl.Translate
local glColor			= gl.Color
local glDepthTest		= gl.DepthTest
local glRotate			= gl.Rotate
local glUnitShape		= gl.UnitShape
local glLoadIdentity	= gl.LoadIdentity

local spGetUnitDefID	= Spring.GetUnitDefID


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

function addBuilders()
	command = {}
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local uDefID = spGetUnitDefID(unitID)
		if builderUnitDefs[uDefID] then
			local random = math.random(1,10)
			buildersOrdered[random][unitID] = true
			builders[unitID] = random
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
	end
end

function clearBuilderCommands(unitID)
	if commandOrdered[unitID] then
		for id, _ in pairs(commandOrdered[unitID]) do
			if command[id] and command[id][unitID] then
				command[id][unitID] = nil
				if #command[id] == 0 then
					command[id] = nil
				end
			end
		end
		commandOrdered[unitID] = nil
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
				local id = Spring.GetUnitTeam(unitID)..'_'..math.abs(cmd.id)..'_'..cmd.params[1]..'_'..cmd.params[2]..'_'..cmd.params[3]
				if showForCreatedUnits or commandCreatedUnits[id] == nil then
					if command[id] == nil then
						command[id] = {id = myCmd }
					end
					command[id][unitID] = true
					if commandOrdered[unitID] == nil then
						commandOrdered[unitID] = {}
					end
					commandOrdered[unitID][id] = true
				end
			end
		end
	end
end

local currentBatch = 1
function widget:GameFrame(gameframe)
	if gameframe % 3 == 1 then
		processNextBatch()
	end
end

function processNextBatch()
	for unitID, random in pairs(buildersOrdered[currentBatch]) do
		checkBuilder(unitID)
	end
	currentBatch = currentBatch + 1
	if currentBatch > 10 then
		currentBatch = 1
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if commandCreatedUnitsIDs[unitID] then
		commandCreatedUnits[commandCreatedUnitsIDs[unitID]] = nil
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local x,y,z = Spring.GetUnitPosition(unitID)
	if command[unitTeam..'_'..unitDefID..'_'..x..'_'..y..'_'..z] then
		command[unitTeam..'_'..unitDefID..'_'..x..'_'..y..'_'..z] = nil
		commandCreatedUnitsIDs[unitID] = unitTeam..'_'..unitDefID..'_'..x..'_'..y..'_'..z
		commandCreatedUnits[unitTeam..'_'..unitDefID..'_'..x..'_'..y..'_'..z] = true
	end
	if builderUnitDefs[unitDefID] then
		local random = math.random(1,10)
		buildersOrdered[random][unitID] = true
		builders[unitID] = random
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, builderID)
	if builders[unitID] then
		buildersOrdered[builders[unitID]][unitID] = nil
		builders[unitID] = nil
		clearBuilderCommands(unitID)
	end
	if commandCreatedUnitsIDs[unitID] then
		commandCreatedUnits[commandCreatedUnitsIDs[unitID]] = nil
	end
end

local sec = 0
local lastUpdate = 0
function widget:Update(dt)
	if Spring.IsGUIHidden() then return end

	sec = sec + dt
	if sec > lastUpdate + 0.1 then
		lastUpdate = sec

		local _, _, isPaused = Spring.GetGameSpeed()
		if isPaused then
			processNextBatch()
		end
	end
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() then return end

	glDepthTest(true)
	for id, units in pairs(command) do
		local myCmd = units.id
		local params = myCmd.params

		local x, y, z = params[1], params[2], params[3]
		local degrees = params[4] ~= nil and params[4] * 90  or 0 -- mex command doesnt supply param 4
		if Spring.IsAABBInView(x-1,y-1,z-1,x+1,y+1,z+1) then
			glPushMatrix()
				glLoadIdentity()
				glTranslate( x, y, z )
				glRotate( degrees, 0, 1.0, 0 )
				glUnitShape(myCmd.id, myCmd.teamid, false, false, false)
			glPopMatrix()
		end
	end
	glDepthTest(false)
	glColor(1, 1, 1, 1)
end

