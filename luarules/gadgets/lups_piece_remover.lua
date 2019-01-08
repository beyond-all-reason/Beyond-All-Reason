--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function gadget:GetInfo()
  return {
    name      = "Lups Piece Remover",
    desc      = "",
    author    = "Nixtux",
    date      = "Dec, 2018",
    license   = "GNU GPL, v2 or later",
    layer     = 10,
    enabled   = true,
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  __           _  _  _
-- (_  \ / |\ | /  |_ | \
-- __)  |  | \| \_ |_ |_/
-- 
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) == 1 then
  Spring.Echo("Bar Models enabled disabling gadget")
  return
end

if (gadgetHandler:IsSyncedCode()) then

  function gadget:UnitFinished(unitID,unitDefID)
    SendToUnsynced("lups_unit_created", unitID, unitDefID)
  end

  function gadget:RecvLuaMsg(msg, playerID)
    if (msg=="lups running") then
      SendToUnsynced("lups_luaui", playerID, true)
    elseif (msg=="lups shutdown") then
      SendToUnsynced("lups_luaui", playerID, false)
    end
  end
else

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--           __           _  _  _
-- | | |\ | (_  \ / |\ | /  |_ | \
-- |_| | \| __)  |  | \| \_ |_ |_/
-- 
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Speed ups

local pairs = pairs
local Lups  --// Lua Particle System
local initialized = false --// if LUPS isn't started yet, we try it once a gameframe later
local lups_luaui = false --// lups running as widget?
local nilDispList

local lupsNoDrawPieceUnits = {
	[UnitDefNames["corfus"].id] = true,
	[UnitDefNames["corafus"].id] = true,
	[UnitDefNames["armjuno"].id] = true,
	[UnitDefNames["corjuno"].id] = true,
}

local function UnitCreated(_,unitID,unitDefID)
  if (lups_luaui and lupsNoDrawPieceUnits[unitDefID]) then
    Spring.UnitRendering.SetLODCount(unitID,1)
    Spring.UnitRendering.SetLODLength(unitID,1,1)
    Spring.UnitRendering.SetMaterial(unitID,1,"defaults3o",{shader="s3o"})
    for pieceID,pieceName in pairs(Spring.GetUnitPieceList(unitID)) do
      if (pieceID~="n") then
        if (pieceName=="globetop")or(pieceName=="globebottom") then
          Spring.UnitRendering.SetPieceList(unitID,1,pieceID,nilDispList)
        else
          Spring.UnitRendering.SetPieceList(unitID,1,pieceID)
        end
      end
    end
  end
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function LupsLuaUI(_,playerID,enabled)
  if (playerID==Spring.GetLocalPlayerID()) then
    lups_luaui = enabled
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Update()
  if (Spring.GetGameFrame()<1) then 
    return
  end
  Lups  = GG['Lups']
  if (Lups) then
    gadgetHandler:AddSyncAction("lups_luaui",               LupsLuaUI)
    gadgetHandler:AddSyncAction("lups_unit_created",        UnitCreated)
    initialized=true
  else
    return
  end
  gadgetHandler:UpdateCallIn("Update")
end

function gadget:Initialize()
  nilDispList = gl.CreateList(function() end)
end


function gadget:Shutdown()
  gadgetHandler:RemoveSyncAction("lups_luaui")
  gadgetHandler:RemoveSyncAction("lups_unit_created")
  gl.DeleteList(nilDispList)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
end