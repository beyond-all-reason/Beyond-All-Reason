--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Tombstones",
    desc      = "Displays tombstones where commanders died",
    author    = "Floris",
    date      = "Sept 2017",
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
  if def.customParams.iscommander and not string.find(def.name,'_scav') then
    commanders[udefID] = def.name
  end
end

function widget:Initialize()
  if armstoneUdefID == nil or corstoneUdefID == nil then
    Spring.Echo('tombstones widget: No tombstones availible')
    widgetHandler:RemoveWidget(self)
  end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if commanders[unitDefID] then
    local x,y,z = Spring.GetUnitPosition(unitID)
    local tombstoneUdefID = armstoneUdefID
    if commanders[unitDefID] == 'corcom' then
      tombstoneUdefID = corstoneUdefID
    end
    z = z - 50
    tombstones[#tombstones+1] = {tombstoneUdefID, unitTeam, x,Spring.GetGroundHeight(x,z),z, ((math.random()-0.5)*25), (14 + (math.random()*14)), ((math.random()-0.5)*18)}
  end
end


function widget:DrawWorldPreUnit()
  local camX, camY, camZ = Spring.GetCameraPosition()
  gl.DepthTest(true)
  for i=1, #tombstones do
    if Spring.IsSphereInView(tombstones[i][3],tombstones[i][4],tombstones[i][5], 30) and math.diag(camX-tombstones[i][3], camY-tombstones[i][4], camZ-tombstones[i][5]) < 5000 then
      tombstones[i][4] = Spring.GetGroundHeight(tombstones[i][3],tombstones[i][5])
      gl.PushMatrix()
        gl.LoadIdentity()
        gl.Translate(tombstones[i][3],tombstones[i][4],tombstones[i][5])
        gl.Rotate(tombstones[i][6],0,1,1)
        gl.Rotate(tombstones[i][7],-1,0,0)
        gl.Rotate(tombstones[i][8],0,0,1)
        gl.UnitShape(tombstones[i][1],tombstones[i][2], false, false, true)
      gl.PopMatrix()
    end
  end
  gl.DepthTest(false)
end

-- preserve data in case of a /luaui reload
function widget:GetConfigData(data)
  return {
	  tombstones = tombstones,
	  gameframe = Spring.GetGameFrame()
  }
end

function widget:SetConfigData(data)
  if Spring.GetGameFrame() > 0 and data.gameframe ~= nil and data.gameframe+1800 > Spring.GetGameFrame() and data.gameframe >= Spring.GetGameFrame() then
    if data.tombstones ~= nil then
      tombstones = data.tombstones
    end
  end
end

