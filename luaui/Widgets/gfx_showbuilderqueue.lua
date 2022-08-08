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
local maxQueueDepth = 2000	-- not literal depth

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
local reinit

local unitshapes = {}
local removedUnitshapes = {}
local numunitshapes = 0
local maxunitshapes = 4096
local command = {}
local builderCommands = {}
local createdUnit = {}
local createdUnitID = {}
local newBuilderCmd = {}

local isBuilder = {}
local unitWaterline = {}
for udefID,def in ipairs(UnitDefs) do
	if def.isBuilder and not def.isFactory and def.buildOptions[1] then
		isBuilder[udefID] = true
	end
	if def.waterline and def.waterline > 0 then
		unitWaterline[udefID] = def.waterline
	end
end

local function addUnitShape(shapeID, unitDefID, px, py, pz, rotationY, teamID)
	if not WG.DrawUnitShapeGL4 then
		widget:Shutdown()
	else
		if numunitshapes < maxunitshapes and not removedUnitshapes[shapeID] then
			unitshapes[shapeID] = WG.DrawUnitShapeGL4(unitDefID, px, py-0.01, pz, rotationY, shapeOpacity, teamID)
			numunitshapes = numunitshapes + 1
			return unitshapes[shapeID]
		else
			return nil
		end
	end
end

local function removeUnitShape(shapeID)
	if not WG.StopDrawUnitShapeGL4 then
		widget:Shutdown()
	elseif shapeID and unitshapes[shapeID] then
		WG.StopDrawUnitShapeGL4(unitshapes[shapeID])
		numunitshapes = numunitshapes - 1
		unitshapes[shapeID] = nil
		removedUnitshapes[shapeID] = true	-- in extreme cases the delayed widget:UnitCommand processing is slower than the actual UnitCreated/Finished, this table is to make sure a unitshape isnt created after
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
						if unitWaterline[unitDefID] then
							groundheight = math.max (groundheight, -1 * unitWaterline[unitDefID])
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
	else
		widget:Shutdown()	-- to clear first
	end

	unitshapes = {}
	removedUnitshapes = {}
	numunitshapes = 0
	builderCommands = {}
	createdUnit = {}
	createdUnitID = {}
	newBuilderCmd = {}
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
		for shapeID, _ in pairs(unitshapes) do
			removeUnitShape(shapeID)
		end
	end
end

function widget:PlayerChanged(playerID)
	local prevFullview = fullview
	local prevMyAllyTeamID = myAllyTeamID
	spec, fullview,_ = Spring.GetSpectatingState()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	if playerID == myPlayerID and prevFullview ~= fullview then
		for _, unitID in pairs(builderCommands) do
			clearbuilderCommands(unitID)
		end
		reinit = true
	end
end

-- process newly given commands batched in Update() (because with huge build queue it eats memory and can crash lua)
function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if isBuilder[unitDefID] then
		clearbuilderCommands(unitID)
		newBuilderCmd[unitID] = os.clock() + 0.13
	end
end


local prevGuiHidden = Spring.IsGUIHidden()
function widget:Update(dt)
	sec = sec + dt
	if reinit then
		reinit = nil
		widget:Initialize()
	elseif sec > lastUpdate + 0.12 then
		lastUpdate = sec

		-- process newly given commands (not done in widget:UnitCommand() because with huge build queue it eats memory and can crash lua)
		local clock = os.clock()
		for unitID, cmdClock in pairs(newBuilderCmd) do
			if clock > cmdClock then
				checkBuilder(unitID)
				newBuilderCmd[unitID] = nil
			end
		end
		removedUnitshapes = {}	-- in extreme cases the delayed widget:UnitCommand processing is slower than the actual UnitCreated/Finished, this table is to make sure a unitshape isnt created after
	end

	if Spring.IsGUIHidden() ~= prevGuiHidden then
		prevGuiHidden = Spring.IsGUIHidden()
		if prevGuiHidden then
			widget:Shutdown()
		else
			widget:Initialize()
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
	-- we need to store all newly created units cause unitcreated can be earlier than our delayed processing of widget:UnitCommand (when a newly queued cmd is first and within builder range)
	createdUnit[id] = unitID
	createdUnitID[unitID] = id
end

local function clearCommandUnit(unitID)
	if createdUnitID[unitID] then
		if unitshapes[createdUnitID[unitID]] then
			removeUnitShape(createdUnitID[unitID])
		end
		removedUnitshapes[createdUnitID[unitID]] = true		-- in extreme cases the delayed widget:UnitCommand processing is slower than the actual UnitCreated/Finished, this table is to make sure a unitshape isnt created after
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
