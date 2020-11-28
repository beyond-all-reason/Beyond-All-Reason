function gadget:GetInfo()
	return {
		name      = "Hats",
		desc      = "Handles cosmetic-only hat behaviour",
		author    = "Beherith",
		date      = "2020",
		license   = "CC BY NC ND",
		layer     = 1000,
		enabled   = true,
	}
end

-- We need to keep track of all hats unitdefs, and watch what happens to them
-- hats, can be equipped by capturing them -- or by being given one?
--    if a commando captures a hat, it is destroyed
--    if a hat is already present on a commander, then it is destroyed
-- if the wearer dies, detach the hat
-- decoys?
--  if decoys cant wear hats, then it becomes obvious
--  so decoys will be able to wear hats
-- giving:
    -- wearer loses hat if given comm with hat
-- hats should not prevent game end! as they arent real units
-- attachunit somehow does not pass the direction, and passes the position of the piece attached to it about 1 frame late
-- consider manually repositioning hats then? could start to get expensive
-- You cant pick up allied hats
-- 

if (not gadgetHandler:IsSyncedCode()) then
	return
end

local DEBUG = false

local unitsWearingHats = {} -- key unitID of wearer, value unitID of hat

local Hats = {}  -- key of unitID of hat, value of wearer unitID

local unitDefHat = {}
for udid, ud in pairs(UnitDefs) do --almost all chickens have dying anims
	if ud.customParams and ud.customParams.subfolder and ud.customParams.subfolder == "other/hats" then
		unitDefHat[udid] = true
	end
end

local unitDefCanWearHats = {
  [UnitDefNames.corcom.id] = true,
  [UnitDefNames.cordecom.id] = true,
  [UnitDefNames.armcom.id] = true,
  [UnitDefNames.armdecom.id] = true,
}


local hasDeathAnim = {
  [UnitDefNames.corkarg.id] = true,
  [UnitDefNames.corthud.id] = true,
  [UnitDefNames.corstorm.id] = true,
  [UnitDefNames.corsumo.id] = true,
}

--Spring.GetUnitPiecePosDir

 --( number unitID, number pieceNum ) -> nil | number posX, number posY, number posZ,
  -- number dirX, number dirZ, number dirY

--Returns piece position and direction in world space. The direction (dirX, dirY, dirZ) is not necessarily normalized. The position is defined as the position of the first vertex of the piece and it defines direction as the direction in which the line --from the first vertex to the second vertex points. 


function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID) -- for unitID reuse, just in case
  if unitDefHat[unitDefID] then 
    
    if DEBUG then Spring.Echo("hat created",unitID, unitDefID, unitTeam, builderID ) end
    Hats[unitID] = -1 
    --Spring.SetUnitNoSelect(unitID,true) -- can it still be targetted though?
    --[[number unitID,
       boolean isBlocking,
       boolean isSolidObjectCollidable,
       boolean isProjectileCollidable,
       boolean isRaySegmentCollidable,
       boolean crushable,
       boolean blockEnemyPushing,
       boolean blockHeightChanges]]--
    Spring.SetUnitNeutral(unitID,true)
    Spring.SetUnitBlocking(unitID,false, false, false, false) -- non blocking while dying
  end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
  if Hats[unitID] ~= nil then 
    if DEBUG then Spring.Echo("A hat was destroyed",unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID) end
    Hats[unitID] = nil 
  end
  if unitsWearingHats[unitID] ~= nil then
    if DEBUG then Spring.Echo("A hat wearing unit was destroyed, freeing hat",unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID) end
    Spring.UnitDetach(unitsWearingHats[unitID])
    unitsWearingHats[unitID] = nil
    Hats[unitID] = -1
    Spring.SetUnitNoSelect(unitID,false) 
    --detach it:
  end
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam)
  if unitsWearingHats[unitID] then
    if DEBUG then Spring.Echo("A hat wearing unit was given, destroying hat",unitID, unitDefID, unitTeam,unitsWearingHats[unitID] ) end
    Spring.DestroyUnit(unitsWearingHats[unitID])
    unitsWearingHats[unitID] = nil
  end
  if Hats[unitID] then
    local hatID = unitID
    
    if DEBUG then Spring.Echo("A hat was given, finding a wearer",hatID, unitDefID, unitTeam ) end
    -- find nearest commander and attach hat onto him?
    local hx, hy, hz = Spring.GetUnitPosition(hatID)
    if hx then
      for ct, nearunitID in pairs (Spring.GetUnitsInCylinder(hx, hz, 200, unitTeam)) do
        local neardefID = Spring.GetUnitDefID(nearunitID)
        if unitDefCanWearHats[neardefID] then
          
          if DEBUG then Spring.Echo("Found a wearer",nearunitID,hatID, unitDefID, unitTeam ) end
          
          local pieceMap = Spring.GetUnitPieceMap(nearunitID)
          local hatPoint = nil
          for pieceName, pieceNum in pairs(pieceMap) do
            if pieceName:find("laserflare", nil, true) then
              hatPoint = pieceNum
              break
            end
          end
          
          if DEBUG then Spring.Echo("Found a point",nearunitID,hatPoint ) end
          
          --Spring.MoveCtrl.Enable(unitID)
          Spring.UnitAttach(nearunitID, hatID, hatPoint) 
          Spring.SetUnitNoDraw(hatID,false)
          Spring.SetUnitNoSelect(hatID,true) 
          --Spring.MoveCtrl.Disable(unitID)
					--Spring.SetUnitLoadingTransport(unitID, nearunitID)
          unitsWearingHats[nearunitID] = hatID
          Hats[hatID] = nearunitID
          return
        end
      end
    end
    if DEBUG then Spring.Echo("Hat was given, but found noone to put it onto, destroying",hatID ) end
    Spring.DestroyUnit(hatID)
  end
end

----------------------------------------------------------------------------
--[[
local dyingUnits = {}

for udid, ud in pairs(UnitDefs) do --almost all chickens have dying anims
	if ud.customParams and ud.customParams.subfolder and ud.customParams.subfolder == "other/chickens" then
		hasDeathAnim[udid] = true
	end
end

local SetUnitNoSelect	= Spring.SetUnitNoSelect
local GiveOrderToUnit	= Spring.GiveOrderToUnit
local SetUnitBlocking = Spring.SetUnitBlocking 
local CMD_STOP = CMD.STOP

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if hasDeathAnim[unitDefID] then
		--Spring.Echo("gadget:UnitDestroyed",unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		SetUnitNoSelect(unitID,true)
    SetUnitBlocking(unitID,false) -- non blocking while dying
		GiveOrderToUnit(unitID, CMD_STOP, {}, 0)
    dyingUnits[unitID] = true
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua) -- do not allow dying units to be moved
  if dyingUnits[unitID] then
    return false
  else
    return true
  end
end

function gadget:RenderUnitDestroyed(unitID, unitDefID, unitTeam) --called when killed anim finishes
  if dyingUnits[unitID] then dyingUnits[unitID] = nil end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID) -- for unitID reuse, just in case
  if dyingUnits[unitID] then dyingUnits[unitID] = nil end
end
]]--