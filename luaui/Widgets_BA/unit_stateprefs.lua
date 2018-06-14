--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "State Prefs",
    desc      = "Sets pre-defined units states.",
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
local chunk, err = loadfile("LuaUI/config/StatesPrefs.lua")
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

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	for ct, unitID in pairs(Spring.GetSelectedUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		unitSet[UnitDefs[unitDefID].name] = unitSet[UnitDefs[unitDefID].name] or {}
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if ctrl and #cmdParams == 1 then
			unitSet[UnitDefs[unitDefID].name][cmdID] = cmdParams[1]
			Spring.Echo("State pref changed")
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  local ud = UnitDefs[unitDefID]
  unitSet[ud.name] = unitSet[ud.name] or {}
  if ((ud ~= nil) and (unitTeam == Spring.GetMyTeamID())) then
  	for cmdID, cmdParam in pairs(unitSet[ud.name]) do
      Spring.GiveOrderToUnit(unitID, cmdID , { cmdParam }, {})
	end
  end
end

function widget:GameOver()
		Spring.Echo("Recorded States Prefs")
		table.save(unitSet, "LuaUI/config/StatesPrefs.lua", "--States prefs")
	    widgetHandler:RemoveWidget(self)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

