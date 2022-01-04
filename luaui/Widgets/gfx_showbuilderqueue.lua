function widget:GetInfo()
	return {
		name      = "Show Builder Queue",
		desc      = "Shows buildings about to be built",
		author    = "WarXperiment, Decay, Floris",
		date      = "February 15, 2010",
		license   = "GNU GPL, v2 or later",
        version   = 8,
        layer     = 55,
		enabled   = true,
    }
end

local shapeOpacity = 0.26
local maxQueueDepth = 500	-- not literal depth

--Changelog
-- before v2 developed by WarXperiment
-- v2 [teh]decay - fixed crash: Error in DrawWorld(): [string "LuaUI/Widgets/unit_showbuild.lua"]:82: bad argument #1 to 'GetTeamColor' (number expected, got no value)
-- v3 [teh]decay - updated for spring 98 engine -- project page on github: https://github.com/jamerlan/unit_showbuild
-- v4 Floris - lots of performance increases
-- v5 Floris - cleanup, polishing and fixes
-- v6 Floris - limited to not show when (would be) icon
-- v7 Floris - simplified/cleanup
-- v8 Floris - GL4 unit shape rendering

local myPlayerID = Spring.GetMyPlayerID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local spec,fullview,_ = Spring.GetSpectatingState()

local spGetCommandQueue = Spring.GetCommandQueue
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitPosition = Spring.GetUnitPosition
local floor = math.floor
local math_halfpi = math.pi / 2

local sec = 0
local lastUpdate = 0

local unitshapes = {}
local numunitshapes = 0
local maxunitshapes = 4096
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

local function addUnitShape(id, unitDefID, px, py, pz, rotationY, teamID)
	--Spring.Echo("addUnitShape",id, unitDefID, UnitDefs[unitDefID].name, px, py, pz, rotationY, teamID)
	if not WG.DrawUnitShapeGL4 then
		widget:Shutdown()
	else
		if numunitshapes < maxunitshapes then 
			unitshapes[id] = WG.DrawUnitShapeGL4(unitDefID, px, py, pz, rotationY, shapeOpacity, teamID)
			numunitshapes = numunitshapes + 1
			return unitshapes[id]
		else
			return nil
		end
	end
end

local function removeUnitShape(id)
	if not WG.StopDrawUnitShapeGL4 then
		widget:Shutdown()
	else
		if id and unitshapes[id] then 
			WG.StopDrawUnitShapeGL4(unitshapes[id])
			numunitshapes = numunitshapes - 1 
			unitshapes[id] = nil
		end
	end
end

local function clearbuilderCommands(unitID)
	if builderCommands[unitID] then
		for id, _ in pairs(builderCommands[unitID]) do
			if command[id] and command[id][unitID] then
				command[id][unitID] = nil
				command[id].builders = command[id].builders - 1
				if command[id].builders == 0 then
					command[id] = nil
					removeUnitShape(id)
				end
			end
		end
		builderCommands[unitID] = nil
	end
end

--local function getFootprintPos(value)	-- not entirely acurate, unsure why
--	local precision = 16		-- (footprint 1 = 16 map distance)
--	return (math.floor(value/precision)*precision)+(precision/2)
--end


local function checkBuilder(unitID)
	clearbuilderCommands(unitID)
	local queueDepth = spGetCommandQueue(unitID, 0)
	if queueDepth and queueDepth > 0 then
		local queue = spGetCommandQueue(unitID, math.min(queueDepth, maxQueueDepth))
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
						local unitDefID = math.abs(cmd.id)
						
						local groundheight = spGetGroundHeight(floor(cmd.params[1]), floor(cmd.params[3]))
						if UnitDefs[unitDefID] and UnitDefs[unitDefID].waterline > 0 then 
							--Spring.Echo(unitDefID,"has a waterline", UnitDefs[unitDefID].waterline)
							groundheight = math.max (groundheight, -1 * UnitDefs[unitDefID].waterline)
						end
						
						addUnitShape(id, math.abs(cmd.id), floor(cmd.params[1]), groundheight, floor(cmd.params[3]), cmd.params[4] and (cmd.params[4] * math_halfpi) or 0, myCmd.teamid)

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


function widget:Initialize()
	if not WG.DrawUnitShapeGL4 then
		widgetHandler:RemoveWidget()
	end

	command = {}
	local allUnits = Spring.GetAllUnits()
	for i=1, #allUnits do
		local unitID = allUnits[i]
		if isBuilder[ spGetUnitDefID(unitID) ] then
			checkBuilder(unitID)
		end
	end
end

function widget:Shutdown()
	if WG.StopDrawUnitShapeGL4 then
		for id, shapeID in pairs(unitshapes) do
			removeUnitShape(id)
		end
	end
end

function widget:PlayerChanged(playerID)
	local prevSpec = spec
	local prevFullview = fullview
	local prevMyAllyTeamID = myAllyTeamID
	spec, fullview,_ = Spring.GetSpectatingState()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	if playerID == myPlayerID or (spec and prevMyAllyTeamID ~= myAllyTeamID or prevFullview ~= fullview) then
		widget:Shutdown()
		widget:Initialize()
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

	if unitshapes[id] then
		removeUnitShape(id)
	end
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
