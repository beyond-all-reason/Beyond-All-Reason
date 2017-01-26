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

local mexDefID = {}
for udid, ud in pairs(UnitDefs) do
	if ud.customParams.metal_extractor then
		mexDefID[udid] = tonumber (ud.customParams.metal_extractor)
	end
end

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
	if ud.customParams.area_mex_def then
		canMex[udid] = true
	end
end

--------------------------------------------------------------------------------
-- Variables
--------------------------------------------------------------------------------

local spotByID = {}
local spotData = {}

local metalSpots = {}
local metalSpotsByPos = {}

local MEX_DISTANCE = 500

--------------------------------------------------------------------------------
-- Command Handling
--------------------------------------------------------------------------------

local sameOrder = {}


function gadget:AllowCommand_GetWantedCommand()	
	local ret = { [CMD.INSERT] = true }
	for id in pairs(mexDefID) do
		ret[-id] = true
	end
	return ret
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if (mexDefID[-cmdID] or (cmdID == CMD.INSERT and cmdParams and mexDefID[-cmdParams[2]])) and metalSpots then
		local x = math.ceil(cmdParams[cmdID == CMD.INSERT and 4 or 1])
		local z = math.ceil(cmdParams[cmdID == CMD.INSERT and 6 or 3])
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
	
	-- This sets a building mask so that only mexDefID can be built on the mex spot
	-- if metalSpots then
		-- local scalingFactor = 2 * Game.squareSize
		-- for i = 1, #metalSpots do
			-- local spot = metalSpots[i]
			-- for x = -3, 3 do
				-- for z = -3, 3 do
					-- Spring.SetSquareBuildingMask(spot.x / scalingFactor + x, spot.z / scalingFactor + z, 2)
				-- end
			-- end
		-- end
	-- end
end

--------------------------------------------------------------------------------
-- Unit Tracker
--------------------------------------------------------------------------------

local inlosTrueTable = {inlos = true}

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if canMex[unitDefID] then
		Spring.InsertUnitCmdDesc(unitID, cmdMex)
	end
	
	if mexDefID[unitDefID] then
		local x,_,z = Spring.GetUnitPosition(unitID)
		local income
		if metalSpots then
			local spotID = metalSpotsByPos[x] and metalSpotsByPos[x][z]
			if spotID then
				spotByID[unitID] = spotID
				spotData[spotID] = {unitID = unitID}
				income = metalSpots[spotID].metal
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
					income = metalSpots[spotindex].metal
				end
			end
		else
			income = GG.IntegrateMetal(x, z)
		end

		if income then
			income = income * mexDefID[unitDefID]
			Spring.SetUnitRulesParam(unitID, "mexIncome", income, inlosTrueTable)
			Spring.SetUnitResourcing(unitID, "cmm", income)
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
	if mexDefID[unitDefID] and spotByID[unitID] then
		spotData[spotByID[unitID]] = nil
		spotByID[unitID] = nil
	end
end
