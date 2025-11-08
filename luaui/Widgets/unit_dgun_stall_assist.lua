local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "DGun Stall Assist",
		desc      = "Waits cons/facs when trying to dgun and stalling",
		author    = "Niobium",
		date      = "2 April 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end


-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

local watchForTime = 3 --How long to monitor the energy level after the dgun command is given

----------------------------------------------------------------
-- Globals
----------------------------------------------------------------
local watchTime = 0
local targetEnergy = 0
local waitedUnits = nil -- nil / waitedUnits[1..n] = uID
local shouldWait = {}
local isFactory = {}

local gameStarted

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spGetActiveCommand = Spring.GetActiveCommand
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

local CMD_DGUN = CMD.DGUN
local CMD_WAIT = CMD.WAIT
local CMD_MOVE = CMD.MOVE
local CMD_REPAIR = CMD.REPAIR
local CMD_RECLAIM = CMD.RECLAIM

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or spGetGameFrame() > 0 then
        maybeRemoveSelf()
    end

	for uDefID, uDef in pairs(UnitDefs) do
		if uDef.buildSpeed > 0 and not uDef.canManualFire and (uDef.canAssist or uDef.buildOptions[1]) then
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
		local selection = Spring.GetSelectedUnitsCounts()
		local stallUnitSelected = false

		for uDefID, _ in next, selection do
			local uDef = UnitDefs[uDefID]
			if uDef and uDef.canManualFire then
				--Look for the weapondef with manual fire and energy cost
				for _, wDef in next, uDef.wDefs do
					if wDef.manualFire and wDef.energyCost and wDef.energyCost > 0 then
						stallUnitSelected = true
						targetEnergy = wDef.energyCost * 1.2 --Add some margin above the energy cost
						break
					end
				end
			end
		end

		if stallUnitSelected then
			watchTime = watchForTime
		end
	else
		watchTime = watchTime - dt

		if waitedUnits and watchTime < 0 then

			local toUnwait = {}
			for i = 1, #waitedUnits do
				local uID = waitedUnits[i]
				local uDefID = spGetUnitDefID(uID)
				if isFactory[uDefID] then
					local uCmds = spGetFactoryCommands(uID, 1)
					if uCmds and #uCmds > 0 and uCmds[1].id == CMD_WAIT then
						toUnwait[#toUnwait + 1] = uID
					end
				else
					local uCmd = spGetUnitCurrentCommand(uID, 1)
					if uCmd and uCmd == CMD_WAIT then
						toUnwait[#toUnwait + 1] = uID
					end
				end
			end
			spGiveOrderToUnitArray(toUnwait, CMD_WAIT, {}, 0)

			waitedUnits = nil
		end
	end

	if watchTime > 0 and not waitedUnits then

		local myTeamID = spGetMyTeamID()
		local currentEnergy, energyStorage = spGetTeamResources(myTeamID, "energy")
		if currentEnergy < targetEnergy and energyStorage >= targetEnergy then

			waitedUnits = {}
			local myUnits = spGetTeamUnits(myTeamID)
			for i = 1, #myUnits do
				local uID = myUnits[i]
				local uDefID = spGetUnitDefID(uID)
				if shouldWait[uDefID] then
					if isFactory[uDefID] then
						local uCmds = spGetFactoryCommands(uID, 1)
						if #uCmds == 0 or uCmds[1].id ~= CMD_WAIT then
							waitedUnits[#waitedUnits + 1] = uID
						end
					else
						local uCmd, _, _, cmdParams = spGetUnitCurrentCommand(uID, 1)
						if not uCmd or (uCmd ~= CMD_WAIT and uCmd ~= CMD_RECLAIM and uCmd ~= CMD_MOVE and (uCmd ~= CMD_REPAIR or (cmdParams and spGetUnitIsBeingBuilt(cmdParams)))) then
							waitedUnits[#waitedUnits + 1] = uID
						end
					end
				end
			end
			spGiveOrderToUnitArray(waitedUnits, CMD_WAIT, {}, 0)
		end
	end
end
