--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "HoldPos Prefs",
    desc      = "Sets pre-defined units on hold position depending on players preferences: change movestate while pressing ctrl to set preference. Preferences are saved when game is over and loaded when widget is loaded.",
    author    = "quantum + Doo",
    date      = "2018",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local unitSet = {}
local chunk, err = loadfile("LuaUI/config/holdposPrefs.lua")
if chunk then
    local tmp = {}
    setfenv(chunk, tmp)
    unitArray = chunk()    
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:PlayerChanged(playerID)
  if Spring.GetSpectatingState() then
 	widget:GameOver()
  end
end

function widget:Initialize()
	unitArray = unitArray or {}
  if Spring.IsReplay() then
	widget:GameOver()
  end
  for i, v in pairs(unitArray) do
    unitSet[i] = v
  end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	if ctrl and cmdID == CMD.MOVE_STATE and unitTeam == Spring.GetMyTeamID() and Spring.IsUnitSelected(unitID) then
		if cmdParams[1] == 0 then --holdpos
			unitSet[UnitDefs[unitDefID].name] = 0
			Spring.Echo("Preference set for: "..UnitDefs[unitDefID].name.." = 0.")
		elseif cmdParams[1] == 1 then --  manoeuver
			unitSet[UnitDefs[unitDefID].name] = 1		
			Spring.Echo("Preference set for: "..UnitDefs[unitDefID].name.." = 1.")
		else
			unitSet[UnitDefs[unitDefID].name] = 2
			Spring.Echo("Preference set for: "..UnitDefs[unitDefID].name.." = 2.")
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  local ud = UnitDefs[unitDefID]
  if ((ud ~= nil) and (unitTeam == Spring.GetMyTeamID())) then
      Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { unitSet[ud.name] }, {})
  end
end

function widget:GameOver()
		Spring.Echo("Recorded MoveState Prefs")
		table.save(unitSet, "LuaUI/config/holdposPrefs.lua", "--hold pos prefs")
	    widgetHandler:RemoveWidget(self)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

