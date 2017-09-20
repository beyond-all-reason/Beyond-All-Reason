--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Tombstones",
    desc      = "Displays tombstones where commanders died",
    author    = "Floris",
    date      = "Sept 2017",
    license   = "GNU GPL, v2 or later",
    layer     = 10,
    enabled   = true  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local tombstones = {}

for udefID,def in ipairs(UnitDefs) do
  if def.name == 'armstone' then
    armstoneUdefID = udefID
  end
  if def.name == 'corstone' then
    corstoneUdefID = udefID
  end
end


function widget:Shutdown()
  for i, tombstone in ipairs(tombstones) do
    gl.DeleteList(tombstone[1])
  end
end


function createTombstoneDrawList(tombstoneUdefID, unitTeam)
  gl.Rotate((math.random()-0.5)*30,0,1,1)
  gl.Rotate(14 + (math.random()*14),-1,0,0)
  gl.Rotate((math.random()-0.5)*20,0,0,1)
  gl.UnitShape(tombstoneUdefID, unitTeam, false, true, true)
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  local ud = UnitDefs[unitDefID]
  if (ud ~= nil and (ud.name == 'armcom' or ud.name == 'corcom')) then
    local x,y,z = Spring.GetUnitPosition(unitID)
    local tombstoneUdefID = armstoneUdefID
    if ud.name == 'corcom' then
      tombstoneUdefID = corstoneUdefID
    end
    table.insert(tombstones, {gl.CreateList(createTombstoneDrawList, tombstoneUdefID, unitTeam), x,y,z, tombstoneUdefID, unitTeam})
  end
end


function widget:DrawWorldPreUnit()
  gl.DepthTest(true)
  gl.Color(1, 1, 1, 1)
  if reloaded ~= nil then
    for i, tombstone in ipairs(tombstones) do
      tombstones[i][1] = gl.CreateList(createTombstoneDrawList, tombstone[5], tombstone[6])
    end
    reloaded = nil
  end
  for i, tombstone in ipairs(tombstones) do
    gl.PushMatrix()
    gl.Translate(tombstone[2],Spring.GetGroundHeight(tombstone[2],tombstone[4]),tombstone[4])
    gl.CallList(tombstone[1])
    gl.PopMatrix()
  end
  gl.DepthTest(false)
end

-- preserve data in case of a /luaui reload
function widget:GetConfigData(data)
  savedTable = {}
  savedTable.tombstones = tombstones
  return savedTable
end

function widget:SetConfigData(data)
  if Spring.GetGameFrame() > 0 then
    if data.tombstones ~= nil then
      tombstones = data.tombstones
      reloaded = true   -- this is used to create displaylist at later time cause player color widget might change the teamcolors
    end
  end
end

