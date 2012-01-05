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
