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
local commanders = {}
for udefID,def in ipairs(UnitDefs) do
  if def.name == 'armstone' then
    armstoneUdefID = udefID
  end
  if def.name == 'corstone' then
    corstoneUdefID = udefID
  end
  if def.customParams.iscommander ~= nil then
    commanders[def.name] = true
  end
end

function widget:Initialize()
  createTombstoneDlist()
end

function widget:Shutdown()
  if tombstonesDlist ~= nil then
    gl.DeleteList(tombstonesDlist)
  end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  local ud = UnitDefs[unitDefID]
  if (ud ~= nil and commanders[ud.name] ~= nil) then
    local x,y,z = Spring.GetUnitPosition(unitID)
    local tombstoneUdefID = armstoneUdefID
    if ud.name == 'corcom' then
      tombstoneUdefID = corstoneUdefID
    end
    table.insert(tombstones, {tombstoneUdefID, unitTeam, x,Spring.GetGroundHeight(x,z),z, math.random(),math.random(),math.random()})
    createTombstoneDlist()
  end
end

local sec = 0
function widget:Update(dt)
  sec = sec + dt
  if sec > 2.7 then
    sec = sec - 2.7
    local changed = false
    for i, tombstone in ipairs(tombstones) do
      if tombstones[i][4] ~= Spring.GetGroundHeight(tombstone[3],tombstone[5]) then
        changed = true
      end
    end
    if changed then
      createTombstoneDlist()
    end
  end
end

function createTombstoneDlist()
  if tombstonesDlist ~= nil then
    gl.DeleteList(tombstonesDlist)
  end
  tombstonesDlist = gl.CreateList(function()
    for i, tombstone in ipairs(tombstones) do
      tombstones[i][4] = Spring.GetGroundHeight(tombstone[3],tombstone[5])
      gl.PushMatrix()
      gl.Translate(tombstone[3],tombstone[4],tombstone[5])
      gl.Rotate((tombstone[6]-0.5)*25,0,1,1)
      gl.Rotate(14 + (tombstone[7]*14),-1,0,0)
      gl.Rotate((tombstone[8]-0.5)*18,0,0,1)
      gl.UnitShape(tombstone[1],tombstone[2], false, true, true)
      gl.PopMatrix()
    end
  end)
end

function widget:DrawWorldPreUnit()
  if tombstonesDlist ~= nil then
    gl.DepthTest(true)
    --gl.CallList(tombstonesDlist)  -- sometimes this seems to make some units another team's color, zooming affects it aswell, strange stuff!

    for i, tombstone in ipairs(tombstones) do
      tombstones[i][4] = Spring.GetGroundHeight(tombstone[3],tombstone[5])
      gl.PushMatrix()
      gl.Translate(tombstone[3],tombstone[4],tombstone[5])
      gl.Rotate((tombstone[6]-0.5)*25,0,1,1)
      gl.Rotate(14 + (tombstone[7]*14),-1,0,0)
      gl.Rotate((tombstone[8]-0.5)*18,0,0,1)
      gl.UnitShape(tombstone[1],tombstone[2], false, true, true)
      gl.PopMatrix()
    end
    gl.DepthTest(false)
  end
end

-- preserve data in case of a /luaui reload
function widget:GetConfigData(data)
  savedTable = {}
  savedTable.tombstones = tombstones
  savedTable.gameframe = Spring.GetGameFrame()
  return savedTable
end

function widget:SetConfigData(data)
  if Spring.GetGameFrame() > 0 and data.gameframe ~= nil and data.gameframe+1800 > Spring.GetGameFrame() and data.gameframe >= Spring.GetGameFrame() then
    if data.tombstones ~= nil then
      tombstones = data.tombstones
    end
  end
end

