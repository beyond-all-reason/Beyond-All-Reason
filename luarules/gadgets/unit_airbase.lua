function gadget:GetInfo()
   return {
      name      = "Airbase Manager",
      desc      = "Automated and manual use of air repair pads",
      author    = "ashdnazg, Bluestone",
      date      = "February 2016",
      license   = "GNU GPL, v2 or later",
      layer     = 1,
      enabled   = true  --  loaded by default?
   }
end

---------------------------------------------------------------------------------
local CMD_LAND_AT_AIRBASE = 35430
local CMD_LAND_AT_SPECIFIC_AIRBASE = 35431

CMD.LAND_AT_AIRBASE = CMD_LAND_AT_AIRBASE
CMD[CMD_LAND_AT_AIRBASE] = "LAND_AT_AIRBASE"
CMD.LAND_AT_SPECIFIC_AIRBASE = CMD_LAND_AT_SPECIFIC_AIRBASE
CMD[CMD_LAND_AT_SPECIFIC_AIRBASE] = "LAND_AT_SPECIFIC_AIRBASE"

local airbaseDefIDs = {
   --Arm
   [UnitDefNames["armasp"].id] = 350, -- distance in elmos for snap onto pad
   [UnitDefNames["armcarry"].id] = 450,
   --Core
   [UnitDefNames["corasp"].id] = 350,
   [UnitDefNames["corcarry"].id] = 450,
}

local snapDist = nil -- default snap distance, if not found in table
    

--------------------------------------------------------------------------------
-- Synced
if (gadgetHandler:IsSyncedCode()) then
--------------------------------------------------------------------------------

local airbases = {} -- airbaseID = { int pieceNum = unitID reservedFor }

local pendingLanders = {} -- unitIDs of planes that want repair and are waiting to be assigned airbases 
local landingPlanes = {} -- planes that are in the process of landing on (including flying towards) airbases; [1]=airbaseID, [2]=pieceNum 
local landedPlanes = {} -- unitIDs of planes that are currently landed in airbases

local previousHealFrame = 0

---------------------------
-- custom commands

local landAtAnyAirbaseCmd = {
   id      = CMD_LAND_AT_AIRBASE,
   name    = "Land At Any\n     Airbase",
   action  = "landatairbase",
   cursor  = 'landatairbase',
   type    = CMDTYPE.ICON,
   tooltip = "Airbase: Tells the unit to land at the nearest available airbase for repairs",
}

local landAtSpecificAirbaseCmd = {
   id      = CMD_LAND_AT_SPECIFIC_AIRBASE,
   name    = "Forceland At\n     Airbase",
   action  = "landatspecificairbase",
   cursor  = 'landatspecificairbase',
   type    = CMDTYPE.ICON_UNIT,
   tooltip = "Airbase: Tells the unit to land at an airbase for repairs ",
}

function InsertLandAtAirbaseCommands(unitID)
   Spring.InsertUnitCmdDesc(unitID, landAtSpecificAirbaseCmd)
   Spring.InsertUnitCmdDesc(unitID, landAtAnyAirbaseCmd)
end

---------------------------------------
-- helper funcs (pads)

function AddAirBase(unitID)
   -- add the pads of this airbase to our register
   local airbasePads = {}
   local pieceMap = Spring.GetUnitPieceMap(unitID)
   for pieceName, pieceNum in pairs(pieceMap) do
      if pieceName:find("land") then
         airbasePads[pieceNum] = false -- value is whether or not the pad is reserved
      end
   end
   airbases[unitID] = airbasePads
end

function FindAirBase(unitID)
   -- find the nearest airbase with a free pad
   local minDist = math.huge
   local closestAirbaseID
   local closestPieceNum
   for airbaseID, _ in pairs(airbases) do
      local pieceNum = CanLandAt(unitID, airbaseID)
      if pieceNum then
         local dist = Spring.GetUnitSeparation(unitID, airbaseID)
         if dist < minDist then
            minDist = dist
            closestAirbaseID = airbaseID
            closestPieceNum = pieceNum
         end
      end
   end
   
   return closestAirbaseID, closestPieceNum
end

function CanLandAt(unitID, airbaseID)
   -- return either false (-> cannot land at this airbase) or the piece number of a free pad within this airbase
   
   -- check that this airbase has pads (needed?)
   local airbasePads = airbases[airbaseID]
   if not airbasePads then
      return false
   end

   -- check that this airbase is on our team
   local unitTeamID = Spring.GetUnitTeam(unitID)
   local airbaseTeamID = Spring.GetUnitTeam(airbaseID)
   if not unitTeamID or not airbaseTeamID or not Spring.AreTeamsAllied(unitTeamID, airbaseTeamID) then
      return false
   end

   -- try to find a vacant pad within this airbase
   local padPieceNum = false
   for pieceNum, reservedBy in pairs(airbasePads) do
      if reservedBy == false then
         padPieceNum = pieceNum
         break
      end
   end
   return padPieceNum
end

---------------------------------------
-- helper funcs (main)

function RemoveLandingPlane(unitID)
   -- free up the pad that this landingPlane had reserved
   if landingPlanes[unitID] then
      local airbaseID, pieceNum = landingPlanes[unitID][1], landingPlanes[unitID][2]
      local airbasePads = airbases[airbaseID]
      if airbasePads then
         airbasePads[pieceNum] = false
      end
      landingPlanes[unitID] = nil
      return
   end
end

function AttachToPad(unitID, airbaseID, padPieceNum)
   Spring.UnitAttach(airbaseID, unitID, padPieceNum)
end

function DetachFromPad(unitID)
   -- if this unitID was in a pad, detach the unit and free that pad
   local airbaseID = Spring.GetUnitTransporter(unitID)
   if not airbaseID then
      return
   end
   local airbasePads = airbases[airbaseID]
   if not airbasePads then
      return
   end
   for pieceNum, reservedBy in pairs(airbasePads) do
      if reservedBy == unitID then
         airbasePads[pieceNum] = false
      end
   end   
   Spring.UnitDetach(unitID)
end

---------------------------------------
-- helper funcs (other)

function NeedsRepair(unitID)
   -- check if this unitID (which is assumed to be a plane) would want to land
   local health, maxHealth = Spring.GetUnitHealth(unitID)
   local landAtState = Spring.GetUnitStates(unitID).autorepairlevel
   return health < maxHealth * landAtState;
end

function IsPlane(unitDefID)
    return UnitDefs[unitDefID].isAirUnit
end

function GetDistanceToPoint(unitID, px,py,pz)
    if not Spring.ValidUnitID(unitID) then return end
    if not px then return end
    
    local ux, uy, uz = Spring.GetUnitPosition(unitID)
    local dx, dy ,dz = ux - px, uy - py, uz - pz
    local dist = dx * dx + dy * dy + dz * dz
    return dist
end


function CheckAll()
   -- check all units to see if any need healing
   local units = Spring.GetAllUnits()
   for _,unitID in ipairs(units) do
      local unitDefID = Spring.GetUnitDefID(unitID)
      if IsPlane(unitDefID) and not landingPlanes[unitID] and not landedPlanes[unitID] and NeedsRepair(unitID) then
         pendingLanders[unitID] = true
      end     
   end  
end

function FlyAway(unitID, airbaseID)
   --
   -- hack, after detaching units don't always continue with their command q 
   Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, {})
   Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, {})
   --
   
   -- if the unit has no orders, tell it to move a little away from the airbase
   local q = Spring.GetUnitCommands(unitID, 0)
   if q==0 then
      local px,_,pz = Spring.GetUnitPosition(airbaseID)
      local theta = math.random()*2*math.pi
      local r = 2.5 * Spring.GetUnitRadius(airbaseID) 
      local tx,tz = px+r*math.sin(theta), pz+r*math.cos(theta)
      local ty = Spring.GetGroundHeight(tx,tz)
      local uDID = Spring.GetUnitDefID(unitID)
      local cruiseAlt = UnitDefs[uDID].wantedHeight 
      Spring.GiveOrderToUnit(unitID, CMD.MOVE, {tx,ty,tz}, {})
   end
end

function HealUnit(unitID, airbaseID, resourceFrames, h, mh)
   if resourceFrames <=0 then return end
   local airbaseDefID = Spring.GetUnitDefID(airbaseID)
   local unitDefID = Spring.GetUnitDefID(unitID)
   local buildSpeed = UnitDefs[airbaseDefID].buildSpeed 
   local timeToBuild = UnitDefs[unitDefID].buildTime / buildSpeed
   local healthGain = timeToBuild / resourceFrames 
   local newHealth = math.min(h+healthGain, mh)
   Spring.SetUnitHealth(unitID, newHealth)
end

function RemoveOrderFromQueue(unitID, cmdID)
   -- hack
   -- we need this because CommandFallback is only called every slow update
   -- and we need to remove commands from the front of the queue when events *actually* happen i.e. in gameframes in between slow update
   -- doing anything else fails to edge cases e.g. unitID is recycle from a landingPlane that dies into a second place that becomes a landedPlane *all* in between slow updates
   Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {cmdID}, {"alt"})
end

---------------------------------------
-- unit creation, destruction, etc

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
   if IsPlane(unitDefID) then
      InsertLandAtAirbaseCommands(unitID)
   end

   local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
   if buildProgress == 1.0 then
      gadget:UnitFinished(unitID, unitDefID, unitTeam)
   end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
   if airbaseDefIDs[unitDefID] then
      AddAirBase(unitID)
   end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
   if not IsPlane(unitDefID) and not airbases[unitID] then return end
   
   RemoveLandingPlane(unitID)

   airbases[unitID] = nil
   landingPlanes[unitID] = nil
   landedPlanes[unitID] = nil
   pendingLanders[unitID] = nil
end

---------------------------------------
-- custom command handling

function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
   -- handle our two custom commands
   
   if cmdID == CMD_LAND_AT_SPECIFIC_AIRBASE then
      if landedPlanes[unitID] then 
         -- this order is now completed
         return true, true
      end
      
      if landingPlanes[unitID] then
         -- this order is not yet completed, call CommandFallback again
         return true, false
      end
      
      -- this order has just reached the top of the command queue and we are not a landingPlane
      -- process the order and make us into a landing plane!

      -- find out if the desired airbase has a free pad
      local airbaseID = cmdParams[1]
      local pieceNum = CanLandAt(unitID, airbaseID)
      if not pieceNum then
         return true, false  -- its not possible to land here
      end

      -- reserve pad
      airbases[airbaseID][pieceNum] = unitID
      landingPlanes[unitID] = {airbaseID, pieceNum}
      --SendToUnsynced("SetUnitLandGoal", unitID, airbaseID, pieceNum)
      return true, false
   end
   
   if cmdID == CMD_LAND_AT_AIRBASE then
      if landingPlanes[unitID] then 
         -- finished processing
         return true, true
      end
   
      pendingLanders[unitID] = true
      return true, false 
   end

   return false
end

---------------------------------------
-- main 
local CMD_SET_WANTED_MAX_SPEED = CMD.SET_WANTED_MAX_SPEED
local CMD_INSERT = CMD.INSERT
local CMD_REMOVE = CMD.REMOVE

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
   return true
end

function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
   -- if a plane is given a command, assume the user wants that command to be actioned and release control
   -- (unless its one of our custom commands, etc)
   if not IsPlane(unitDefID) then return end
   if cmdID == CMD_LAND_AT_AIRBASE then return end
   if cmdID == CMD_LAND_AT_SPECIFIC_AIRBASE then return end --fixme: case of wanting to force land at a different pad than current reserved
   if cmdID == CMD_SET_WANTED_MAX_SPEED then return end -- i hate SET_WANTED_MAX_SPEED   
   if cmdID == CMD_INSERT and cmdParams[2] == CMD_LAND_AT_AIRBASE then return end
   if cmdID == CMD_INSERT and cmdParams[2] == CMD_LAND_AT_SPECIFIC_AIRBASE then return end
   if cmdID == CMD_REMOVE then return end
   
   -- release control of this plane
   if landingPlanes[unitID] then 
      RemoveLandingPlane(unitID) 
   elseif landedPlanes[unitID] then
      DetachFromPad(unitID) 
   end
   
   -- and remove it from our book-keeping 
   -- (in many situations, unless the user changes the RepairAt level, it will be quickly reinserted, but we have to assume that's what they want!)
   landingPlanes[unitID] = nil
   landedPlanes[unitID] = nil
   pendingLanders[unitID] = nil
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID)
   -- when a plane is damaged, check to see if it needs repair, move to pendingLanders if so
   --Spring.Echo("damaged", unitID)
   if IsPlane(unitDefID) and not landingPlanes[unitID] and not landedPlanes[unitID] and NeedsRepair(unitID) then
      pendingLanders[unitID] = true
   end
end

function gadget:GameFrame(n)
   -- main loop --
   -- in all cases, planes/pads may die at any time, and UnitDestroyed will take care of the book-keeping

   -- very occasionally, check all units to see if any planes (outside of our records) that need repair
   -- add them to pending landers, if so
   if n%72==0 then
      CheckAll()
   end   

   -- assign airbases & pads to planes in pendingLanders, if possible
   -- once done, move into landingPlanes
   if n%16==0 then
      for unitID, _ in pairs(pendingLanders) do
         --Spring.Echo("pending", unitID)
         local airbaseID, pieceNum = FindAirBase(unitID)
         if airbaseID then 
            -- reserve pad, give landing order to unit
            airbases[airbaseID][pieceNum] = unitID
            landingPlanes[unitID] = {airbaseID, pieceNum}
            pendingLanders[unitID] = nil
            Spring.SetUnitLoadingTransport(unitID, airbaseID)
            Spring.GiveOrderToUnit(unitID, CMD.INSERT, {0, CMD_LAND_AT_SPECIFIC_AIRBASE, 0, airbaseID}, {"alt"}) --fixme: it fails without "alt", but idk why 
            RemoveOrderFromQueue(unitID, CMD_LAND_AT_AIRBASE) -- hack!
         end
      end
   end
   
   -- fly towards pad
   -- once 'close enough' snap into pads, then move into landedPlanes
   if n%2==0 then
      for unitID, t in pairs(landingPlanes) do
         --Spring.Echo("landing", unitID)
         local airbaseID, padPieceNum = t[1], t[2]
         local px, py, pz = Spring.GetUnitPiecePosDir(airbaseID, padPieceNum)
         local dist = GetDistanceToPoint(unitID, px,py,pz)
         if dist then
            -- check if we're close enough, attach if so
            local r = Spring.GetUnitRadius(unitID)
            local airbaseDefID = Spring.GetUnitDefID(airbaseID)
            if airbaseDefID and dist < airbaseDefIDs[airbaseDefID] then 
               -- land onto pad
               landingPlanes[unitID] = nil
               landedPlanes[unitID] = airbaseID
               AttachToPad(unitID, airbaseID, padPieceNum)
               Spring.SetUnitLoadingTransport(unitID, nil)
               RemoveOrderFromQueue(unitID, CMD_LAND_AT_SPECIFIC_AIRBASE) -- hack!
            else
               -- fly towards pad (the pad may move!)
               Spring.SetUnitLandGoal(unitID, px, py, pz, r)
            end
         end
      end
   end
   
   -- heal landedPlanes
   -- release if fully healed
   if n%8==0 then
      local resourceFrames = (n-previousHealFrame)/30
      for unitID, airbaseID in pairs(landedPlanes) do
         --Spring.Echo("landed", unitID)
         local h,mh = Spring.GetUnitHealth(unitID)
         if h and h==mh then
            -- fully healed
            landedPlanes[unitID] = nil
            DetachFromPad(unitID)
            FlyAway(unitID, airbaseID)
            --Spring.Echo("released", unitID)
         elseif h then
            -- still needs healing
            HealUnit(unitID, airbaseID, resourceFrames, h, mh)
         end   
      end
      previousHealFrame = n
   end
end

function gadget:Initialize()
   -- fixme: when using new transport mechanics, this is the proper way to define airbases
   for unitDefID, unitDef in pairs(UnitDefs) do
      if unitDef.isAirBase then
         airbaseDefIDs[unitDefID] = airbaseDefIDs[unitDefID] or snapDist 
      end
   end

   -- dummy UnitCreated events for existing units, to handle luarules reload
   -- release any planes currently attached to anything else
   local allUnits = Spring.GetAllUnits()
   for i=1,#allUnits do
      local unitID = allUnits[i]
      local unitDefID = Spring.GetUnitDefID(unitID)
      local teamID = Spring.GetUnitTeam(unitID)
      gadget:UnitCreated(unitID, unitDefID)
      
      local transporterID = Spring.GetUnitTransporter(unitID)
      if transporterID and IsPlane(unitDefID) then
         Spring.UnitDetach(unitID)
      end
   end
   
end

--------------------------------------------------------------------------------
-- Unsynced
else
--------------------------------------------------------------------------------

local landAtAirBaseCmdColor = {0.50, 1.00, 1.00, 0.8} -- same colour as repair

function gadget:Initialize()
   Spring.SetCustomCommandDrawData(CMD_LAND_AT_SPECIFIC_AIRBASE, "landatairbase", landAtAirBaseCmdColor, false)
   Spring.SetCustomCommandDrawData(CMD_LAND_AT_AIRBASE, "landatspecificairbase", landAtAirBaseCmdColorr, false)
   Spring.AssignMouseCursor("landatspecificairbase", "cursorrepair", false, false) 
end

local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spIsUnitSelected = Spring.IsUnitSelected
local spGetSelectedUnits = Spring.GetSelectedUnits

local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local amISpec = Spring.GetSpectatingState()

local strUnit = "unit"

function gadget:PlayerChanged()
   myTeamID = Spring.GetMyTeamID()
   myAllyTeamID = Spring.GetMyAllyTeamID()
   amISpec = Spring.GetSpectatingState()
end

function gadget:DefaultCommand()
   local mx, my = spGetMouseState()
   local s, targetID = spTraceScreenRay(mx, my)
   if s ~= strUnit then
      return false
   end

   if not spAreTeamsAllied(myTeamID, spGetUnitTeam(targetID)) then
      return false
   end

   local targetDefID = spGetUnitDefID(targetID)
   if not (UnitDefs[targetDefID].isAirBase or airbaseDefIDs[targetDefID]) then
      return false
   end

   local sUnits = spGetSelectedUnits()
   for i=1,#sUnits do
      local unitID = sUnits[i]
      if UnitDefs[spGetUnitDefID(unitID)].canFly then
         return CMD_LAND_AT_SPECIFIC_AIRBASE
      end
   end
   return false
end


--------------------------------------------------------------------------------
end
