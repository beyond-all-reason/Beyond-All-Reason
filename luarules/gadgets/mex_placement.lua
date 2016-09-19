--------------------------------------------------------------------------------
-- SYNCED
--------------------------------------------------------------------------------
if (not gadgetHandler:IsSyncedCode()) then
	return
end


function gadget:GetInfo()
  return {
    name      = "Mex Placement",
    desc      = "Controls mex placement and income",
    author    = "Google Frog", -- 
    date      = "21 April 2012",
    license   = "GNU GPL, v2 or later",
    layer     = -10,
    enabled   = true  --  loaded by default?
  }
end

include("LuaRules/Configs/customcmds.h.lua")

--------------------------------------------------------------------------------
-- Command Definition
--------------------------------------------------------------------------------

local mexDefID = UnitDefNames["cormex"].id

local cmdMex = {
	id      = CMD_AREA_MEX,
	type    = CMDTYPE.ICON_AREA,
	tooltip = 'Area Mex: Click and drag to queue metal extractors in an area.',
	name    = 'Mex',
	cursor  = 'Repair',
	action  = 'areamex',
	params  = {}, 
}

local canMex = {}
for udid, ud in ipairs(UnitDefs) do 
	for i, option in ipairs(ud.buildOptions) do 
		if mexDefID == option then
			canMex[udid] = true
			--Spring.Echo(ud.name)
		end
	end
end


--------------------------------------------------------------------------------
-- Variables
--------------------------------------------------------------------------------

local spotByID = {}
local spotData = {}

local metalSpots = {}
local metalSpotsByPos = {}

local MEX_DISTANCE = 50

--------------------------------------------------------------------------------
-- Command Handling
--------------------------------------------------------------------------------

local sameOrder = {}

function gadget:AllowCommand_GetWantedCommand()	
	return {[-mexDefID] = true, [CMD.INSERT] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if (cmdID == -mexDefID or (cmdID == CMD.INSERT and cmdParams and cmdParams[2] == -mexDefID)) and metalSpots then
		local x = math.ceil(cmdParams[1])
		local z = math.ceil(cmdParams[3])
		if x and z then
			if metalSpotsByPos[x] and metalSpotsByPos[x][z] then
				return true
			else
				local _,_,_,isAI = Spring.GetTeamInfo(teamID)
				if not isAI then 
					return false;
				else
					local nearestspot, dist, spotindex = GetClosestMetalSpot(x, z)
					if spotData[spotindex] == nil and dist < MEX_DISTANCE then
						return true
					else
						return false
					end
				end
			end
		end
	end
	return true
end

function gadget:Initialize()
	metalSpots = GG.metalSpots
	metalSpotsByPos = GG.metalSpotsByPos
	-- register command
	gadgetHandler:RegisterCMDID(CMD_AREA_MEX)
	-- load active units
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local teamID = Spring.GetUnitTeam(unitID)
		gadget:UnitCreated(unitID, unitDefID, teamID)
	end
end

--------------------------------------------------------------------------------
-- Unit Tracker
--------------------------------------------------------------------------------

local inlosTrueTable = {inlos = true}

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if canMex[unitDefID] then
		Spring.InsertUnitCmdDesc(unitID, cmdMex)
	end
	
	if unitDefID == mexDefID then
		local x,_,z = Spring.GetUnitPosition(unitID)
		if metalSpots then
			local spotID = metalSpotsByPos[x] and metalSpotsByPos[x][z]
			if spotID then
				spotByID[unitID] = spotID
				spotData[spotID] = {unitID = unitID}
				Spring.SetUnitRulesParam(unitID, "mexIncome", metalSpots[spotID].metal, inlosTrueTable)
				--GG.UnitEcho(unitID,spotID)
			else
		        local nearestspot, dist, spotindex = GetClosestMetalSpot(x, z)
				if spotData[spotindex] == nil and dist < MEX_DISTANCE then
				    local _,_,_,isAI = Spring.GetTeamInfo(unitTeam)
				    if not isAI then 
				        Spring.SetUnitPosition(unitID, nearestspot.x, nearestspot.z)
				    end
					spotByID[unitID] = spotindex
					spotData[spotindex] = {unitID = unitID}
					Spring.SetUnitRulesParam(unitID, "mexIncome", metalSpots[spotindex].metal, inlosTrueTable)
				end
			end
		else
			local metal = GG.IntegrateMetal(x, z)
			Spring.SetUnitRulesParam(unitID, "mexIncome", metal, inlosTrueTable)
		end
	end
end

function GetClosestMetalSpot(x, z) --is used by single mex placement, not used by areamex
	local bestSpot
	local bestDist = math.huge
	local bestIndex 
	for i = 1, #metalSpots do
		local spot = metalSpots[i]
		local dx, dz = x - spot.x, z - spot.z
		local dist = dx*dx + dz*dz
		if dist < bestDist then
			bestSpot = spot
			bestDist = dist
			bestIndex = i
		end
	end
	return bestSpot, math.sqrt(bestDist), bestIndex
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitDefID == mexDefID and spotByID[unitID] then
		spotData[spotByID[unitID]] = nil
		spotByID[unitID] = nil
	end
end
