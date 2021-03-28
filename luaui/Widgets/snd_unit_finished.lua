function widget:GetInfo()
  return {
    name      = "Unit Finished Sounds",
    desc      = "Plays a sound when a unit is built",
    author    = "TheFatController",
    date      = "30 Sep 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local activateSounds = {}
local GetUnitPosition = Spring.GetUnitPosition
local PlaySoundFile = Spring.PlaySoundFile
local configVolume = tonumber(Spring.GetConfigString("snd_volunitreply") or 100)
local volume = ((configVolume or 100) / 100)

function widget:Initialize()
  for unitDefID,defs in pairs(UnitDefs) do
    if defs["sounds"]["select"][1] and (not (defs["sounds"]["activate"][1])) then
      activateSounds[unitDefID] = (defs["sounds"]["select"][1]["name"])
    end
  end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if activateSounds[unitDefID] then
    local x,y,z = GetUnitPosition(unitID)
    PlaySoundFile(activateSounds[unitDefID],volume,x,y,z, 'sfx')
  end
end
  
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------