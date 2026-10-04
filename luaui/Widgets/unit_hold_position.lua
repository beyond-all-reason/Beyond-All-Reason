
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Everything hold position",
		desc    = "Sets every unit built or received to hold position (except air)",
		author  = "Hobo Joe",
		date    = "April 2024",
		license = "GNU GPL, v2 or later",
		layer   = -9999, -- Run before everything, so that other movestate handling will override it
		enabled = false
	}
end


-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID

local myTeamID = spGetMyTeamID()

local isAir = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isAirUnit or unitDef.customParams.airfactory then
		isAir[unitDefID] = true
	end
end

local function setToHoldPos(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID then
		if not isAir[unitDefID] then
			Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	setToHoldPos(unitID, unitDefID, unitTeam)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	setToHoldPos(unitID, unitDefID, newTeam)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	setToHoldPos(unitID, unitDefID, unitTeam)
end

---------------------------------------------------------------

local function maybeRemoveSelf()
	if Spring.IsReplay() or Spring.GetSpectatingState() then
		widgetHandler.RemoveWidget()
	end
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
	myTeamID = spGetMyTeamID()
end

function widget:Initialize()
	maybeRemoveSelf()
end

function widget:GameStart()
	widget:PlayerChanged()
end