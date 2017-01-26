VFS.Include("LuaRules/Utilities/versionCompare.lua")
local reverseCompat = not Spring.Utilities.IsCurrentVersionNewerThan(100, 0)

if reverseCompat then

-- $Id:$
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- exported functions:
-- Spring.UnitRendering.GetLODCount(unitID) -> int
-- Spring.UnitRendering.ActivateMaterial(unitID,lod) -> nil
-- Spring.UnitRendering.DeactivateMaterial(unitID,lod) -> nil
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (SendToUnsynced) then
	return
end

local unit_lods = {}

local origSetLODCount = Spring.UnitRendering.SetLODCount

function Spring.UnitRendering.SetLODCount(unitID,lod_count)
  unit_lods[unitID] = lod_count
  origSetLODCount(unitID,lod_count)
end

function Spring.UnitRendering.GetLODCount(unitID)
  return unit_lods[unitID] or 0
end



local unitActiveMats = {}
local curHighestLOD = 0

function Spring.UnitRendering.ActivateMaterial(unitID,lod)
  local actMats = unitActiveMats[unitID]
  if (not actMats) then
    actMats = {current = math.huge}
    unitActiveMats[unitID] = actMats
  end

  local lod_count = Spring.UnitRendering.GetLODCount(unitID)
  if (lod_count < lod) then
    Spring.UnitRendering.SetLODCount(unitID,lod)
  end

  actMats[lod] = true

  if (lod > curHighestLOD) then
    curHighestLOD = lod
  end

  if (lod <= actMats.current) then
    actMats.current = lod
    Spring.UnitRendering.SetMaterialLastLOD(unitID, "opaque", lod)
  end
end


function Spring.UnitRendering.DeactivateMaterial(unitID,lod)
  local actMats = unitActiveMats[unitID]
  if (not actMats) then
    return
  end

  actMats[lod] = nil

  if (actMats.current == lod) then
    --// detect next available material
    for i=1,curHighestLOD do
      if (actMats[i]) then
        actMats.current = i
        Spring.UnitRendering.SetMaterialLastLOD(unitID, "opaque", i)
        return
      end
    end

    --// none material active
    unitActiveMats[unitID] = nil
    Spring.UnitRendering.SetMaterialLastLOD(unitID, "opaque", 0)
    Spring.UnitRendering.SetLODCount(unitID,0)
  end
end

else -- reverseCompat

-- $Id:$
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- exported functions:
-- Spring.UnitRendering.GetLODCount(unitID) -> int
-- Spring.UnitRendering.ActivateMaterial(unitID,lod) -> nil
-- Spring.UnitRendering.DeactivateMaterial(unitID,lod) -> nil
-- Spring.FeatureRendering.GetLODCount(featureID) -> int
-- Spring.FeatureRendering.ActivateMaterial(featureID,lod) -> nil
-- Spring.FeatureRendering.DeactivateMaterial(featureID,lod) -> nil
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (SendToUnsynced) then
  return
end

local unitRendering = {
  lods = {},
  curHighestLOD = 0,

  activeMats = {},

  spSetLODCount = Spring.UnitRendering.SetLODCount,
  spSetMaterialLastLOD = Spring.UnitRendering.SetMaterialLastLOD,
}

local featureRendering = {
  lods = {},
  curHighestLOD = 0,

  activeMats = {},

  spSetLODCount = Spring.FeatureRendering.SetLODCount,
  spSetMaterialLastLOD = Spring.FeatureRendering.SetMaterialLastLOD,
}

local function SetLODCount(rendering, objectID, lod_count)
  rendering.lods[objectID] = lod_count
  rendering.spSetLODCount(objectID, lod_count)
end

local function GetLODCount(rendering, objectID)
  return rendering.lods[objectID] or 0
end

local function ActivateMaterial(rendering, objectID, lod)
  local activeMats = rendering.activeMats[objectID]
  if not activeMats then
    activeMats = {current = math.huge}
    rendering.activeMats[objectID] = activeMats
  end
  
  local lod_count = GetLODCount(rendering, objectID)
  if lod_count < lod then
    SetLODCount(rendering, objectID, lod)
  end

  activeMats[lod] = true

  if lod > rendering.curHighestLOD then
    rendering.curHighestLOD = lod
  end

  if lod <= activeMats.current then
    activeMats.current = lod
    rendering.spSetMaterialLastLOD(objectID, "opaque", lod)
  end
end


local function DeactivateMaterial(rendering, objectID, lod)
  local activeMats = rendering.activeMats[objectID]
  if not activeMats then
    return
  end

  activeMats[lod] = nil

  if activeMats.current == lod then
    --// detect next available material
    for i = 1, rendering.curHighestLOD do
      if activeMats[i] then
        activeMats.current = i
        rendering.spSetMaterialLastLOD(objectID, "opaque", i)
        return
      end
    end

    --// none material active
    rendering.activeMats[objectID] = nil
    rendering.spSetMaterialLastLOD(objectID, "opaque", 0)
    SetLODCount(rendering, objectID, 0)
  end
end

function Spring.UnitRendering.SetLODCount(unitID, lod_count)
  SetLODCount(unitRendering, unitID, lod_count)
end

function Spring.UnitRendering.GetLODCount(unitID)
  return GetLODCount(unitRendering, unitID)
end

function Spring.UnitRendering.ActivateMaterial(unitID, lod)
  ActivateMaterial(unitRendering, unitID, lod)
end

function Spring.UnitRendering.DeactivateMaterial(unitID, lod)
  DeactivateMaterial(unitRendering, unitID, lod)
end

function Spring.FeatureRendering.SetLODCount(featureID, lod_count)
  SetLODCount(featureRendering, featureID, lod_count)
end

function Spring.FeatureRendering.GetLODCount(featureID)
  return GetLODCount(featureRendering, featureID)
end

function Spring.FeatureRendering.ActivateMaterial(featureID, lod)
  ActivateMaterial(featureRendering, featureID, lod)
end

function Spring.FeatureRendering.DeactivateMaterial(featureID, lod)
  DeactivateMaterial(featureRendering, featureID, lod)
end

end