local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "DGun Stall Assist",
		desc = "Waits cons/facs when trying to dgun and stalling",
		author = "Niobium",
		date = "2 April 2010",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local getSelectedUnitsByDefID = Spring.GetSelectedUnitsSorted -- replaced in init

local watchForTime = 3 --How long to monitor the energy level after the dgun command is given
local waitLandingFrames = 150 --How long a wait order can take to reach the sim

----------------------------------------------------------------
-- Globals
----------------------------------------------------------------
local watchTime = 0.0
local targetEnergy = 0
local waitedUnits = nil -- nil / waitedUnits[1..n] = uID
local waitedFactories ---@type integer[]? -- nil / waitedFactories[1..n] = uID
local waitedFrame = 0
local shouldWait = {}
local isFactory = {}

-- The energy a def's manual fire costs, with a margin.
local manualFireEnergy = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canManualFire then
		for _, weaponDef in pairs(unitDef.wDefs) do
			if weaponDef.manualFire and weaponDef.energyCost and weaponDef.energyCost > 0 then
				manualFireEnergy[unitDefID] = weaponDef.energyCost * 1.2
				break
			end
		end
	end
end

local function selectedManualFireEnergy()
	for unitDefID in pairs(getSelectedUnitsByDefID()) do
		if manualFireEnergy[unitDefID] then
			return manualFireEnergy[unitDefID]
		end
	end
end

local gameStarted

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spGetActiveCommand = Spring.GetActiveCommand
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetMyTeamID = Spring.GetLocalTeamID
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

local CMD_DGUN = CMD.DGUN
local CMD_WAIT = CMD.WAIT
local CMD_MOVE = CMD.MOVE
local CMD_REPAIR = CMD.REPAIR
local CMD_RECLAIM = CMD.RECLAIM
local CMD_REMOVE = CMD.REMOVE
local CMD_OPT_ALT = CMD.OPT_ALT

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
	getSelectedUnitsByDefID = WG.UnitSelection and WG.UnitSelection.GetUnitsByDefID or Spring.GetSelectedUnitsSorted

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
		local energy = selectedManualFireEnergy()
		if energy then
			targetEnergy = energy
			watchTime = watchForTime
		end
	else
		watchTime = watchTime - dt

		if waitedUnits and watchTime < 0 then
			-- This is overkill e.g. it also clears waits on already-waited units.
			spGiveOrderToUnitArray(waitedUnits, CMD_REMOVE, CMD_WAIT, CMD_OPT_ALT)
			waitedUnits = nil
		end

		if waitedFactories and watchTime < 0 then
			local toUnwait = {}
			for i = 1, #waitedFactories do
				local uID = waitedFactories[i]
				local uCmds = spGetFactoryCommands(uID, 1)
				if uCmds and #uCmds > 0 and uCmds[1].id == CMD_WAIT then
					toUnwait[#toUnwait + 1] = uID
				end
			end
			-- CMD_REMOVE would destroy the factory's current build. We have to rely on WAIT.
			local waitsLanded = #toUnwait > 0 or #waitedFactories == 0
			if waitsLanded or spGetGameFrame() >= waitedFrame + waitLandingFrames then
				spGiveOrderToUnitArray(toUnwait, CMD_WAIT)
				waitedFactories = nil
			end
		end
	end

	if watchTime > 0 and not waitedUnits and not waitedFactories then
		local myTeamID = spGetMyTeamID()
		local currentEnergy, energyStorage = spGetTeamResources(myTeamID, "energy")
		if currentEnergy < targetEnergy and energyStorage >= targetEnergy then
			waitedUnits = {}
			waitedFactories = {}
			local myUnits = spGetTeamUnits(myTeamID)
			for i = 1, #myUnits do
				local uID = myUnits[i]
				local uDefID = spGetUnitDefID(uID)
				if shouldWait[uDefID] then
					if isFactory[uDefID] then
						local uCmds = spGetFactoryCommands(uID, 1)
						if #uCmds == 0 or uCmds[1].id ~= CMD_WAIT then
							waitedFactories[#waitedFactories + 1] = uID
						end
					else
						local uCmd, _, _, cmdParams = spGetUnitCurrentCommand(uID, 1)
						if
							not uCmd
							or (
								uCmd ~= CMD_WAIT
								and uCmd ~= CMD_RECLAIM
								and uCmd ~= CMD_MOVE
								and (uCmd ~= CMD_REPAIR or (cmdParams and spGetUnitIsBeingBuilt(cmdParams)))
							)
						then
							waitedUnits[#waitedUnits + 1] = uID
						end
					end
				end
			end
			spGiveOrderToUnitArray(waitedUnits, CMD_WAIT)
			spGiveOrderToUnitArray(waitedFactories, CMD_WAIT)
			waitedFrame = spGetGameFrame() -- wait for commands to be received
		end
	end
end
