--
-- code review version. Thanks go to JK, KingRaptor, Jools
--
function gadget:GetInfo()
   return {
      name      = "feature placer v3",
      desc      = "Spawns Features and Units",
      author      = "Gnome, Smoth",
      date      = "August 2008, updated 7/11/2014",
      license      = "PD",
      layer      = -1,
      enabled      = true  --  loaded by default?
   }
end

-- these are here because I like the way they look
local   spSetUnitNeutral      = Spring.SetUnitNeutral
local   spSetUnitBlocking      = Spring.SetUnitBlocking
local   spSetUnitRotation       = Spring.SetUnitRotation
local   spSetUnitLosState      = Spring.SetUnitLosState
local   spSetUnitAlwaysVisible   = Spring.SetUnitAlwaysVisible
local   spCreateUnit         = Spring.CreateUnit
local   spGetGaiaTeamID         = Spring.GetGaiaTeamID
local   spCreateFeature         = Spring.CreateFeature
local   spGetGroundHeight      = Spring.GetGroundHeight
local   spEcho               = Spring.Echo

-- SYNCED only
if not gadgetHandler:IsSyncedCode() then
   return
end

local   rotationMultiplier   = math.pi / 32768
local   gaiaTeamID         = spGetGaiaTeamID()
local   featureSetFile      = "mapconfig/featureplacer/config.lua"
local   losState         = {los=true, prevLos=true, contRadar=true, radar=true}

----------------------------------------------------
-- PARAMS
-- featureList = table of values to storing feature
--      name, location x, location z, rotation
--       Ex: {   name = 'artbushweird1lo',
--            x = 7847,
--            z = 4152,
--            rot = "0" },
----------------------------------------------------
function ProcessFeatures(featureList)
   spEcho("placing " .. #featureList .. " feature(s)")
   for _,fDef in pairs(featureList) do
      if FeatureDefNames[fDef.name] then
         local yPlacement   = spGetGroundHeight(fDef.x,fDef.z)+5

         -- kludge for rand rot
         if fDef.rot == "-1" then
            fDef.rot = Spring.GetHeadingFromVector (   math.random(-100,100)/100,
                                             math.random(-100,100)/100)
         end
         -- end kludge

         spCreateFeature(fDef.name, fDef.x, yPlacement, fDef.z, fDef.rot)
      else
         spEcho("featureplacer warning: invalid feature name", fDef.name)
      end
   end
end

----------------------------------------------------
-- Places units
-- PARAMS
-- unitList = table of values to storing a unit
--      name, location x, location z, rotation
--       Ex: {   name = 'badger',
--            x = 7847,
--            z = 4152,
--            rot = "0" },
----------------------------------------------------
function ProcessUnits(unitList)
   spEcho("placing " .. #unitList .. " unit(s)")
   for _,uDef in pairs(unitList) do
      if UnitDefNames[uDef.name] then
         local unitId = spCreateUnit(uDef.name, uDef.x, 0, uDef.z, 0, gaiaTeamID)
         if unitId ~= nil then
            local unitRotation   = -uDef.rot * rotationMultiplier
            spSetUnitRotation(unitId, 0, unitRotation, 0)
            spSetUnitNeutral(unitId,true)
            spSetUnitBlocking(unitId,true)
            spSetUnitAlwaysVisible(unitId,true)
            spSetUnitLosState(unitId,0,losState)
            for _,allyTeam in ipairs(Spring.GetAllyTeamList()) do
               Spring.SetUnitLosMask(unitId, allyTeam, {prevLos=true,})
            end
         end
      else
         spEcho("featureplacer warning: invalid unit def name", bDef.name)
      end
   end
end

----------------------------------------------------
-- Places neutral structures
-- PARAMS
-- buildingList = table of values to storing buidking
--      name, location x, location z, rotation
--       Ex: {   name = 'neutralfueltank1',
--            x = 7847,
--            z = 4152,
--            rot = "north" },
----------------------------------------------------
function ProcessBuildings(buildingList)
   spEcho("placing " .. #buildingList .. " building(s)")
   for _,bDef in pairs(buildingList) do
      if UnitDefNames[bDef.name] then
         local buildingId = spCreateUnit(bDef.name, bDef.x, 0, bDef.z, bDef.rot, gaiaTeamID)
         if buildingId ~= nil then
            spSetUnitNeutral(buildingId,true)
            spSetUnitBlocking(buildingId,true)
            spSetUnitAlwaysVisible(buildingId,true)
            spSetUnitLosState(buildingId,0,losState)
            for _,allyTeam in ipairs(Spring.GetAllyTeamList()) do
               Spring.SetUnitLosMask(buildingId, allyTeam, {prevLos=true,})
            end
         end
      else
         spEcho("featureplacer warning: invalid building def name", bDef.name)
      end
   end
end

----------------------------------------------------
-- gadgethander:GamePreload
----------------------------------------------------
function gadget:GamePreload()
   if not VFS.FileExists(featureSetFile)   then
      spEcho("No feature placer objects loaded")
      return
   end

   featurecfg      = VFS.Include(featureSetFile)
   unitList      = featurecfg.unitlist
   featureList      = featurecfg.objectlist
   buildingList   = featurecfg.buildinglist

   if ( unitList )   then
      ProcessUnits(unitList)
   end
   if ( featureList )   then
      ProcessFeatures(featureList)
   end
   if ( buildingList )   then
      ProcessBuildings(buildingList)
   end
end
