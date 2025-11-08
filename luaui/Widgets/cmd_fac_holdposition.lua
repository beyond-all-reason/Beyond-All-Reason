
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Factory hold position",
		desc    = "Sets new factories, and all units they build, to hold position automatically (except aircraft)",
		author  = "Hobo Joe (original by Masta Ali)",
		date    = "April 2024",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID

local myTeamID = spGetMyTeamID()

local landFactories = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory and not unitDef.customParams.airfactory then
		landFactories[unitDefID] = true
	end
end

-- Units inherit the movestate of the lab that produced them, so we only need to set the factory movestate
function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  if unitTeam == myTeamID then
    if landFactories[unitDefID] then
      Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
    end
  end
end

----------------------------------------------
----------------------------------------------


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


