
if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name      = "Factory Unblocking",
    desc      = "This prevents exiting units get stuck on the newly initiated (big) unit",
    author    = "Floris",
    date      = "September 2020",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

local setBlockingOnFinished = {}
local factoryUnits = {}
local isFactory = {}
local canFly = {}
local waitFlickerUnits = {}
local pendingWaitFrame = {}
local pendingWaitToggleFrame = {}
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local CMD_WAIT = CMD.WAIT
local WAIT_FLICKER_DELAY_FRAMES = Game.gameSpeed * 1
local WAIT_FLICKER_TOGGLE_DELAY_FRAMES = 1
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory and #unitDef.buildOptions > 0 then
		isFactory[unitDefID] = true
	end
	if unitDef.canFly then
		canFly[unitDefID] = true
	end

	--"Dragon" needs a flicker of the "wait" command to prevent it from getting stuck on factory exit
	if unitDef.name == "corcrwh" then
		waitFlickerUnits[unitDefID] = true
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isFactory[unitDefID] then
		factoryUnits[unitID] = isFactory[unitDefID]
	end
	if setBlockingOnFinished[unitID] then
		if canFly[unitDefID] then
			-- to make sure air units do not set their ground to blocking
			-- to prevent rare case of aircraft already in takeoff state perma-blocking a factory

			-- also the second false is to clear CSTATE_BIT_SOLIDOBJECTS, so landing aircraft do not claim dumb spots as blocking
			-- TODO, engine fix to prevent this nonsense
			Spring.SetUnitBlocking(unitID, false, false)
			if waitFlickerUnits[unitDefID] then
				pendingWaitFrame[unitID] = spGetGameFrame() + WAIT_FLICKER_DELAY_FRAMES
			end
		else
			Spring.SetUnitBlocking(unitID, true)
		end
		setBlockingOnFinished[unitID] = nil
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if factoryUnits[builderID] then
		-- first false is to set blocking on ground
		Spring.SetUnitBlocking(unitID, false)
		setBlockingOnFinished[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	factoryUnits[unitID] = nil
	setBlockingOnFinished[unitID] = nil
	pendingWaitFrame[unitID] = nil
	pendingWaitToggleFrame[unitID] = nil
end

function gadget:GameFrame(frame)
	if next(pendingWaitFrame) then
		for unitID, waitFrame in pairs(pendingWaitFrame) do
			if frame >= waitFrame then
				local unitDefID = spGetUnitDefID(unitID)
				if unitDefID and waitFlickerUnits[unitDefID] then
					spGiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
					pendingWaitToggleFrame[unitID] = frame + WAIT_FLICKER_TOGGLE_DELAY_FRAMES
				end
				pendingWaitFrame[unitID] = nil
			end
		end
	end
	if next(pendingWaitToggleFrame) then
		for unitID, toggleFrame in pairs(pendingWaitToggleFrame) do
			if frame >= toggleFrame then
				local unitDefID = spGetUnitDefID(unitID)
				if unitDefID and waitFlickerUnits[unitDefID] then
					spGiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
				end
				pendingWaitToggleFrame[unitID] = nil
			end
		end
	end
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeamID = Spring.GetUnitTeam(unitID)
		gadget:UnitFinished(unitID, unitDefID, unitTeamID)
	end
end
