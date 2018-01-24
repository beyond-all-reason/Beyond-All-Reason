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
  if armstoneUdefID == nil or corstoneUdefID == nil then
    Spring.Echo('tombstones widget: No tombstones availible')
    widgetHandler:RemoveWidget(self)
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
    table.insert(tombstones, {tombstoneUdefID, unitTeam, x,Spring.GetGroundHeight(x,z),z, ((math.random()-0.5)*25), (14 + (math.random()*14)), ((math.random()-0.5)*18)})
  end
end


function widget:DrawWorldPreUnit()
  gl.DepthTest(true)
  for i, tombstone in ipairs(tombstones) do
    tombstones[i][4] = Spring.GetGroundHeight(tombstone[3],tombstone[5])
    gl.PushMatrix()
      gl.LoadIdentity()
      gl.Translate(tombstone[3],tombstone[4],tombstone[5])
      gl.Rotate(tombstone[6],0,1,1)
      gl.Rotate(tombstone[7],-1,0,0)
      gl.Rotate(tombstone[8],0,0,1)
      gl.UnitShape(tombstone[1],tombstone[2], false, false, true)
    gl.PopMatrix()
  end
  gl.DepthTest(false)
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

