local widget = widget ---@type Widget

function widget:GetInfo()
  return {
	name		= "ImmobileBuilder",
	desc		= "Sets immobile builders to MANEUVER, with a FIGHT command",
	author		= "trepan",
	date		= "Jan 8, 2007",
	license		= "GNU GPL, v2 or later",
	layer		= 0,
	enabled		= true
  }
end


-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

local CMD_MOVE_STATE		= CMD.MOVE_STATE
local CMD_FIGHT				= CMD.FIGHT
local spGetMyTeamID			= Spring.GetMyTeamID
local spGetTeamUnits		= Spring.GetTeamUnits
local spGetUnitDefID		= Spring.GetUnitDefID
local spGetUnitPosition		= Spring.GetUnitPosition
local spGiveOrderToUnit		= Spring.GiveOrderToUnit
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand

local halfMapSizeX = Game.mapSizeX / 2
local halfMapSizeZ = Game.mapSizeZ / 2

local myTeamID = spGetMyTeamID()

local gameStarted

-- Set immobile builders to the MANEUVER movestate, and give them a FIGHT order
-- Too close to the unit will drop the order so we add 50 distance

local isImmobileBuilder = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and not unitDef.canMove and not unitDef.isFactory then
		isImmobileBuilder[unitDefID] = true
	end
end

local function setupUnit(unitID)
	local x, y, z = spGetUnitPosition(unitID)
	if x and y and z then
	    if (x > halfMapSizeX) then -- Avoid issuing commands outside map
	      x = x - 50
	    else
	      x = x + 50
	    end
	    if (z > halfMapSizeZ) then
	      z = z - 50
	    else
	      z = z + 50
	    end
		-- Meta enables reclaim enemy units, alt autoresurrect (if available)
		spGiveOrderToUnit(unitID, CMD_FIGHT, { x, y, z }, {"meta"})
	end
end

local function maybeRemoveSelf()
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
	myTeamID = spGetMyTeamID()
end

function widget:Initialize()
    if Spring.IsReplay() or spGetGameFrame() > 0 then
        maybeRemoveSelf()
    end
	for _,unitID in ipairs(spGetTeamUnits(spGetMyTeamID())) do
		local unitDefID = spGetUnitDefID(unitID)
		if isImmobileBuilder[unitDefID] then
			spGiveOrderToUnit(unitID, CMD_MOVE_STATE, 1, 0)
			setupUnit(unitID)
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam ~= spGetMyTeamID() then
		return
	end
	if isImmobileBuilder[unitDefID] then
		spGiveOrderToUnit(unitID, CMD_MOVE_STATE, 1, 0)
		setupUnit(unitID)
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeamID then
		return
	end
	if isImmobileBuilder[unitDefID] then
		setupUnit(unitID)
	end
end

function widget:UnitCommand(unitID, unitDefID, _, cmdID, _, cmdOpts)
	if isImmobileBuilder[unitDefID] and cmdOpts.shift and cmdID ~= CMD_FIGHT then
		local count = spGetUnitCommandCount(unitID)
		if count == 0 then
			return
		end
		local cmdID, opts, tag = spGetUnitCurrentCommand(unitID, count)
		if cmdID and cmdID == CMD_FIGHT then
			spGiveOrderToUnit(unitID, CMD.REMOVE, tag, 0)
		end
	end
end
