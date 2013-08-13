
function widget:GetInfo()
	return {
		name      = "DGun Stall Assist",
		desc      = "Waits cons/facs when trying to dgun and stalling",
		author    = "Niobium",
		date      = "2 April 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = false  --  loaded by default?
	}
end

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local targetEnergy = 600
local watchForTime = 5

----------------------------------------------------------------
-- Globals
----------------------------------------------------------------
local watchTime = 0
local waitedUnits = nil -- nil / waitedUnits[1..n] = uID
local shouldWait = {} -- shouldWait[uDefID] = true / nil
local isFactory = {} -- isFactory[uDefID] = true / nil

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spGetActiveCommand = Spring.GetActiveCommand
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetUnitCommands = Spring.GetUnitCommands
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSpectatingState = Spring.GetSpectatingState

local CMD_DGUN = CMD.DGUN
local CMD_WAIT = CMD.WAIT

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function widget:Initialize()
	
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end
	
	for uDefID, uDef in pairs(UnitDefs) do
		if (uDef.buildSpeed > 0) and uDef.canAssist and (not uDef.customParams.iscommander) then
			shouldWait[uDefID] = true
			if uDef.isFactory then
				isFactory[uDefID] = true
			end
		end
	end
end

function widget:Update(dt)
	
	local _, activeCmdID = spGetActiveCommand()
	if activeCmdID == CMD_DGUN then
		watchTime = watchForTime
	else
		watchTime = watchTime - dt
		
		if waitedUnits and (watchTime < 0) then
			
			local toUnwait = {}
			for i = 1, #waitedUnits do
				local uID = waitedUnits[i]
				local uDefID = spGetUnitDefID(uID)
				local uCmds = isFactory[uDefID] and spGetFactoryCommands(uID, 1) or spGetUnitCommands(uID, 1)
				if uCmds and (#uCmds > 0) and (uCmds[1].id == CMD_WAIT) then
					toUnwait[#toUnwait + 1] = uID
				end
			end
			spGiveOrderToUnitArray(toUnwait, CMD_WAIT, {}, {})
			
			waitedUnits = nil
		end
	end
	
	if (watchTime > 0) and (not waitedUnits) then
		
		if spGetSpectatingState() then
			widgetHandler:RemoveWidget(self)
			return
		end
		
		local myTeamID = spGetMyTeamID()
		local currentEnergy, energyStorage = spGetTeamResources(myTeamID, "energy")
		if (currentEnergy < targetEnergy) and (energyStorage >= targetEnergy) then
			
			waitedUnits = {}
			local myUnits = spGetTeamUnits(myTeamID)
			for i = 1, #myUnits do
				local uID = myUnits[i]
				local uDefID = spGetUnitDefID(uID)
				if shouldWait[uDefID] then
					local uCmds = isFactory[uDefID] and spGetFactoryCommands(uID, 1) or spGetUnitCommands(uID, 1)
					if (#uCmds == 0) or (uCmds[1].id ~= CMD_WAIT) then
						waitedUnits[#waitedUnits + 1] = uID
					end
				end
			end
			spGiveOrderToUnitArray(waitedUnits, CMD_WAIT, {}, {})
		end
	end
end
