function widget:GetInfo()
	return {
		name      = "Show Builder Queue",
		desc      = "Shows buildings about to be built",
		author    = "WarXperiment, Decay, Floris",
		date      = "February 15, 2010",
		license   = "GNU GPL, v2 or later",
        version   = 7,
        layer     = 55,
		enabled   = true,
    }
end

local maxDisplayedUnits = 70
local dontShowWhenDistIcon = true

--Changelog
-- before v2 developed by WarXperiment
-- v2 [teh]decay - fixed crash: Error in DrawWorld(): [string "LuaUI/Widgets/unit_showbuild.lua"]:82: bad argument #1 to 'GetTeamColor' (number expected, got no value)
-- v3 [teh]decay - updated for spring 98 engine -- project page on github: https://github.com/jamerlan/unit_showbuild
-- v4 Floris - lots of performance increases
-- v5 Floris - cleanup, polishing and fixes
-- v6 Floris - limited to not show when (would be) icon
-- v7 Floris - simplified/cleanup

local myPlayerID = Spring.GetMyPlayerID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local spec,fullview,_ = Spring.GetSpectatingState()

local spGetCommandQueue = Spring.GetCommandQueue
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetGroundHeight = Spring.GetGroundHeight
local spIsAABBInView = Spring.IsAABBInView
local spGetCameraPosition = Spring.GetCameraPosition
local spGetUnitPosition = Spring.GetUnitPosition
local diag = math.diag
local floor = math.floor

local glPushMatrix = gl.PushMatrix
local glLoadIdentity = gl.LoadIdentity
local glTranslate = gl.Translate
local glRotate = gl.Rotate
local glUnitShape = gl.UnitShape
local glPopMatrix = gl.PopMatrix

local disticon = Spring.GetConfigInt("UnitIconDist", 200)

local chobbyInterface

local sec = 0
local lastUpdate = 0

local command = {}
local builderCommands = {}
local createdUnit = {}
local createdUnitID = {}
local newBuilderCmd = {}

local isBuilder = {}
for udefID,def in ipairs(UnitDefs) do
	if def.isBuilder and not def.isFactory and def.buildOptions[1] then
		isBuilder[udefID] = true
	end
end

local function getFootprintPos(value)	-- not entirely acurate, unsure why
	local precision = 16		-- (footprint 1 = 16 map distance)
	return (math.floor(value/precision)*precision)+(precision/2)
end

local function clearbuilderCommands(unitID)
	if builderCommands[unitID] then
		for id, _ in pairs(builderCommands[unitID]) do
			if command[id] and command[id][unitID] then
				command[id][unitID] = nil
				command[id].builders = command[id].builders - 1
				if command[id].builders == 0 then
					command[id] = nil
				end
			end
		end
		builderCommands[unitID] = nil
	end
end

local function checkBuilder(unitID)
	clearbuilderCommands(unitID)
	local queueDepth = spGetCommandQueue(unitID, 0)
	if queueDepth and queueDepth > 0 then
		local queue = spGetCommandQueue(unitID, math.min(queueDepth, 200))
		for i=1, #queue do
			local cmd = queue[i]
			if cmd.id < 0 then
				--if cmd.params[1] then
				--	cmd.params[1] = getFootprintPos(cmd.params[1])
				--	cmd.params[3] = getFootprintPos(cmd.params[3])
				--end
				local myCmd = {
					id = -cmd.id,
					teamid = spGetUnitTeam(unitID),
					params = cmd.params
				}
				local id = myCmd.teamid..'_'..math.abs(cmd.id)..'_'..floor(cmd.params[1])..'_'..floor(cmd.params[3])
				if createdUnit[id] == nil then
					if command[id] == nil then
						command[id] = {id = myCmd, builders = 0}
					end
					command[id][unitID] = true
					command[id].builders = command[id].builders + 1
					if builderCommands[unitID] == nil then
						builderCommands[unitID] = {}
					end
					builderCommands[unitID][id] = true
				end
			end
		end
	end
end

local function init()
	command = {}
	local allUnits = Spring.GetAllUnits()
	for i=1, #allUnits do
		local unitID = allUnits[i]
		if isBuilder[ spGetUnitDefID(unitID) ] then
			checkBuilder(unitID)
		end
	end
end

function widget:Initialize()
	if Spring.GetGameFrame() > 0 then
		init()
	end
end

function widget:PlayerChanged(playerID)
	local prevSpec = spec
	local prevFullview = fullview
	local prevMyAllyTeamID = myAllyTeamID
	spec, fullview,_ = Spring.GetSpectatingState()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	if playerID == myPlayerID or (spec and prevMyAllyTeamID ~= myAllyTeamID or prevFullview ~= fullview) then
		init()
	end
end

-- process newly given commands batched in Update() (because with huge build queue it eats memory and can crash lua)
function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if isBuilder[unitDefID] then
		newBuilderCmd[unitID] = os.clock() + 0.05
	end
end

function widget:Update(dt)
	sec = sec + dt
	if sec > lastUpdate + 0.12 then
		lastUpdate = sec
		disticon = math.min(350, Spring.GetConfigInt("UnitIconDist", 200))

		-- process newly given commands (not done in widgetUnitCommand() because with huge build queue it eats memory and can crash lua)
		local clock = os.clock()
		for unitID, cmdClock in pairs(newBuilderCmd) do
			if clock > cmdClock then
				checkBuilder(unitID)
				newBuilderCmd[unitID] = nil
			end
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local x,_,z = spGetUnitPosition(unitID)
	local id = unitTeam..'_'..unitDefID..'_'..floor(x)..'_'..floor(z)
	command[id] = nil
	-- we need to store all newly created units cause unitcreated can be earlier than our delayed processing of widget:UnitCommand (when a newly queued cmd is first and withing builder range)
	createdUnit[id] = true
	createdUnitID[unitID] = id
end

local function clearCommandUnit(unitID)
	if createdUnitID[unitID] then
		command[createdUnitID[unitID]] = nil
		createdUnit[createdUnitID[unitID]] = nil
		createdUnitID[unitID] = nil
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	clearCommandUnit(unitID)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, builderID)
	if isBuilder[unitDefID] then
		newBuilderCmd[unitID] = nil
		clearbuilderCommands(unitID)
	end
	clearCommandUnit(unitID)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface or Spring.IsGUIHidden() then return end

	local camX, camY, camZ = spGetCameraPosition()
	local dist
	local commandVisible = 0
	for _, units in pairs(command) do
		local myCmd = units.id
		local params = myCmd.params
		local x, y, z = params[1], params[2], params[3]
		if spIsAABBInView(x-1,y-1,z-1,x+1,y+1,z+1) then
			if dontShowWhenDistIcon then
				dist = diag(camX-x, camY-y, camZ-z)		-- note it doesnt result in comparable distance as disticon
			end
			if not dontShowWhenDistIcon or dist < disticon*30 then
				local degrees = params[4] ~= nil and params[4] * 90  or 0 -- mex command doesnt supply param 4
				glPushMatrix()
				glLoadIdentity()
				glTranslate( x, y, z )
				glRotate( degrees, 0, 1, 0 )
				glUnitShape(myCmd.id, myCmd.teamid, false, false, false)
				glPopMatrix()
				commandVisible = commandVisible + 1
				if commandVisible >= maxDisplayedUnits then
					break
				end
			end
		end
	end
end
