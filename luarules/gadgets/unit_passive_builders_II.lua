
function gadget:GetInfo()
	return {
		name      = 'Passive Builders II',
		desc      = '',
		author    = 'Niobium',
		date      = 'April 2011',
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
local passiveBuilders = {} -- passiveBuilders[uID] = nil / bool
local canPassive = {} -- canPassive[uDefID] = nil / true
local requiresMetal = {} -- requiresMetal[uDefID] = bool
local requiresEnergy = {} -- requiresEnergy[uDefID] = bool
local teamList = {} -- teamList[1..n] = teamID
local teamMetalStalling = {} -- teamStalling[teamID] = nil / bool
local teamEnergyStalling = {} -- teamStalling[teamID] = nil / bool

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

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:Initialize()
    for uDefID, uDef in pairs(UnitDefs) do
        canPassive[uDefID] = ((uDef.canAssist and uDef.buildSpeed > 0) or #uDef.buildOptions > 0)
        requiresMetal[uDefID] = (uDef.metalCost > 1) -- T1 metal makers cost 1 metal.
        requiresEnergy[uDefID] = (uDef.energyCost > 0) -- T1 solars cost 0 energy.
    end
    teamList = Spring.GetTeamList()
end

function gadget:UnitCreated(uID, uDefID, uTeam)
    if canPassive[uDefID] then
        spInsertUnitCmdDesc(uID, cmdPassiveDesc)
    end
end

function gadget:AllowCommand(uID, uDefID, uTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
    if cmdID == CMD_PASSIVE and canPassive[uDefID] then
        local cmdIdx = spFindUnitCmdDesc(uID, CMD_PASSIVE)
        local cmdDesc = spGetUnitCmdDescs(uID, cmdIdx, cmdIdx)[1]
        cmdDesc.params[1] = cmdParams[1]
        spEditUnitCmdDesc(uID, cmdIdx, cmdDesc)
        passiveBuilders[uID] = (cmdParams[1] == 1)
        return false -- Allowing command causes command queue to be lost if command is unshifted
    end
    return true
end

function gadget:UnitDestroyed(uID, uDefID, uTeam)
    passiveBuilders[uID] = nil
end

function gadget:GameFrame(n)
    if n % 32 == 0 then
        for i = 1, #teamList do
            local teamID = teamList[i]
            local mCur, mStor, mPull, mInc, mExp, mShare, mSent, mRec, mExc = spGetTeamResources(teamID, 'metal')
            local eCur, eStor, ePull, eInc, eExp, eShare, eSent, eRec, eExc = spGetTeamResources(teamID, 'energy')
            -- stabilize the situation if storage is small
            if ePull > eExp then
                eCur = eCur - (ePull - eExp)
            end
            if eExc > 0 then
                eCur = eCur + eExc
            end            
            if mPull > mExp then
                mCur = mCur - (mPull - mExp)
            end
            if mExc > 0 then
                mCur = mCur + mExc
            end
            -- never consider it a stall if the actual combined income is higher than the total expense
            teamMetalStalling[teamID] = (mCur < 0.5 * mPull) and ((mInc + mRec) <= (mExp + mSent))
            teamEnergyStalling[teamID] = (eCur < 0.5 * ePull) and ((eInc + eRec) <= (eExp + eSent))
        end
    end
end

function gadget:AllowUnitBuildStep(builderID, builderTeamID, uID, uDefID, step)
    return (step <= 0) or not (passiveBuilders[builderID] and ((teamMetalStalling[builderTeamID] and requiresMetal[uDefID]) or (teamEnergyStalling[builderTeamID] and requiresEnergy[uDefID])))
end
