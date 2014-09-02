
function gadget:GetInfo()
	return {
		name      = 'Passive Builders II',
		desc      = '',
		author    = 'BD',
		date      = 'Why is date even relevant',
		license   = 'GNU GPL, v2 or later',
		layer     = 0,
		enabled   = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

----------------------------------------------------------------
-- Var
----------------------------------------------------------------
local CMD_PASSIVE = 34571
local stallMargin = 0.01

local canPassive = {} -- canPassive[uDefID] = nil / true
local cost = {} -- cost[uDefID] = {metal=value,energy=value}
local costID = {}
local teamStalling = {} -- teamStalling[teamID] = {resName=leftover}
local passiveCons = {}

local ruleName = "passiveBuilders"

local resTable = {"metal","energy"}

local cmdPassiveDesc = {
	  id      = CMD_PASSIVE,
	  name    = 'passive',
	  action  = 'passive',
	  type    = CMDTYPE.ICON_MODE,
	  tooltip = 'Building Mode: Passive wont build when stalling',
	  params  = {0, 'Active', 'Passive'}
}

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamList = Spring.GetTeamList
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitCurrentBuildPower = Spring.GetUnitCurrentBuildPower
local simSpeed = Game.gameSpeed

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
	for uDefID, uDef in pairs(UnitDefs) do
		canPassive[uDefID] = ((uDef.canAssist and uDef.buildSpeed > 0) or #uDef.buildOptions > 0)
		cost[uDefID] = {}
		cost[uDefID].buildTime = uDef.buildTime
		for _,resName in pairs(resTable) do
			cost[uDefID][resName] = uDef[resName .. "Cost"]
		end
	end
	for _,unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

function gadget:UnitCreated(uID, uDefID, uTeam)
	if canPassive[uDefID] then
		spInsertUnitCmdDesc(uID, cmdPassiveDesc)
	end
	passiveCons[uID] = spGetUnitRulesParam(uID,ruleName) == 1 or nil
	costID[uID] = cost[uDefID]
end

function gadget:UnitDestroyed(uID, uDefID, uTeam)
	costID[uID] = nil
	passiveCons[uID] = nil
end


function gadget:AllowCommand(uID, uDefID, uTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID == CMD_PASSIVE and canPassive[uDefID] then
		local cmdIdx = spFindUnitCmdDesc(uID, CMD_PASSIVE)
		local cmdDesc = spGetUnitCmdDescs(uID, cmdIdx, cmdIdx)[1]
		cmdDesc.params[1] = cmdParams[1]
		spEditUnitCmdDesc(uID, cmdIdx, cmdDesc)
		spSetUnitRulesParam(uID,ruleName,cmdParams[1])
		passiveCons[uID] = cmdParams[1] == 1 or nil
		return false -- Allowing command causes command queue to be lost if command is unshifted
	end
	return true
end


function gadget:GameFrame(n)
	--with 500 nanos, turning on/off the gadget has no visible impact on sim load -> it's ok to calculate every frame
	for _,teamID in pairs(spGetTeamList()) do
		--calculate how much pull passive cons would require
		local passiveConsPull = {}
		for unitID in pairs(passiveCons) do
			local builtUnit = spGetUnitIsBuilding(unitID)
			if builtUnit then
				local targetCosts = costID[builtUnit]
				local step = spGetUnitCurrentBuildPower(unitID)/targetCosts.buildTime
				for _,resName in pairs(resTable) do
					local costTick = targetCosts[resName]*step
					passiveConsPull[resName] = (passiveConsPull[resName] or 0 ) + costTick
				end
			end
		end
		teamStalling[teamID] = {}
		for _,resName in pairs(resTable) do
			local cur, stor, pull, inc, exp, share, sent, rec, exc = spGetTeamResources(teamID, resName)
			stor = stor * share -- consider capacity only up to the share slider
			local reservedExpense = pull - (passiveConsPull[resName] or 0) -- we don't want to touch this part of expense
			teamStalling[teamID][resName] = cur - stor*stallMargin +(inc+rec-sent-reservedExpense)/simSpeed --amount of res available to assign to passive builders ( in current sim frame )
		end
	end
end

function gadget:AllowUnitBuildStep(builderID, builderTeamID, uID, uDefID, step)
	if step <= 0 or not passiveCons[builderID] then
		return true
	end
	local newPulls = {}
	local wouldStall = false
	for resName,allocatedPull in pairs(teamStalling[builderTeamID]) do
		newPulls[resName] = allocatedPull - step*cost[uDefID][resName]
		if newPulls[resName] <= 0 then
			wouldStall = true
		end
	end
	if not wouldStall then
		teamStalling[builderTeamID] = newPulls
	end
	return not wouldStall
end
