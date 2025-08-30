local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name = 'Debug Damage Efficiency Areas',
    desc = 'Visualize damage efficiency areas as colored squares with raw values',
    author = 'tetrisface',
    date = '2025-08-29',
    license = 'GNU GPL, v2 or later',
    version = 0.1,
    layer = -1123123,
    enabled = false,
    depends = {'gl4'}
  }
end

local config = {
  tileSize = 192, -- Size of each tile (should match PveTargeting tileSize)
  maxViewDistance = 3000.0, -- Distance at which the visualization no longer renders
  textScale = 200.0, -- Scale of the text labels (much larger for visibility)
  showDamageValues = true, -- Whether to show damage dealt/taken values
  showEfficiency = true, -- Whether to show efficiency values
  showTopUnits = true, -- Whether to show top 3 performing units
  showBottomUnits = true, -- Whether to show bottom 3 performing units (can be verbose)
  opacity = 0.7 -- Overall opacity of the visualization
}

local damageAreas = {}
local lastUpdateFrame = 0
local updateInterval = 30 -- Update every 30 frames (1 second at 30fps)

local shader = nil
local vbo = nil
local vao = nil

local vsSrc =
  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout (location = 0) in vec3 position; // xz world position, y is unused
layout (location = 1) in vec4 color; // rgba color

//__ENGINEUNIFORMBUFFERDEFS__

out vec4 v_color;
out vec2 v_uv;

void main() {
    v_color = color;
    v_uv = position.xy; // Use position as UV for texturing if needed

    vec4 worldPos = vec4(position.x, position.y, position.z, 1.0);
    gl_Position = cameraViewProj * worldPos;
}
]]

local fsSrc =
  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

in vec4 v_color;
in vec2 v_uv;

out vec4 fragColor;

void main() {
    fragColor = v_color;
}
]]

local function goodbye(reason)
  Spring.Echo('Damage Efficiency Areas GL4 widget exiting with reason: ' .. reason)
  widgetHandler:RemoveWidget()
end

local function initShader()
  local engineUniformBufferDefs = gl.LuaShader.GetEngineUniformBufferDefs()
  vsSrc = vsSrc:gsub('//__ENGINEUNIFORMBUFFERDEFS__', engineUniformBufferDefs)
  fsSrc = fsSrc:gsub('//__ENGINEUNIFORMBUFFERDEFS__', engineUniformBufferDefs)

  shader =
    gl.LuaShader(
    {
      vertex = vsSrc,
      fragment = fsSrc
    },
    'damageEfficiencyShader'
  )

  local shaderCompiled = shader:Initialize()
  if not shaderCompiled then
    goodbye('Failed to compile damage efficiency shader')
    return
  end
end

local function updateDamageAreas()
  local currentFrame = Spring.GetGameFrame()
  if currentFrame - lastUpdateFrame < updateInterval then
    return
  end

  lastUpdateFrame = currentFrame

  -- Get damage areas from gamerulesparams
  local areasJson = Spring.GetGameRulesParam('pveDamageEfficiencyAreas')
  if not areasJson or areasJson == '' then
    damageAreas = {}
    return
  end

  local success, areas = pcall(Json.decode, areasJson)
  if not success or not areas then
    Spring.Echo('Failed to decode damage areas JSON')
    damageAreas = {}
    return
  end
  damageAreas = type(areas) == 'table' and areas or {}
end

local function getEfficiencyColor(efficiency)
  -- Color scheme: red (bad) -> yellow -> green (good)
  if efficiency <= 0.5 then
    -- Red to yellow
    local t = efficiency / 0.5
    return {1.0, t, 0.0, config.opacity}
  elseif efficiency <= 1.0 then
    -- Yellow to green
    local t = (efficiency - 0.5) / 0.5
    return {1.0 - t, 1.0, 0.0, config.opacity}
  else
    -- Green to bright green for very good efficiency
    local t = math.min((efficiency - 1.0) / 1.0, 1.0)
    return {0.0, 1.0, t * 0.5, config.opacity}
  end
end

local function createTileVertices(x, z, tileSize, color)
  local halfSize = tileSize / 2
  local vertices = {}

  -- Check if tile is within map bounds
  local mapSizeX = Game.mapSizeX
  local mapSizeZ = Game.mapSizeZ

  if x - halfSize < 0 or x + halfSize > mapSizeX or
     z - halfSize < 0 or z + halfSize > mapSizeZ then
    -- Tile is outside map bounds, return empty vertices
    return {}
  end

  -- Get terrain height at the center of the tile and add a larger offset above ground to prevent z-fighting
  local terrainHeight = (Spring.GetGroundHeight(x, z) or 0) + 15

  -- Create a square with 2 triangles (6 vertices)
  -- Triangle 1
  table.insert(vertices, x - halfSize) -- x1
  table.insert(vertices, terrainHeight) -- y1 (terrain height)
  table.insert(vertices, z - halfSize) -- z1
  table.insert(vertices, color[1]) -- r1
  table.insert(vertices, color[2]) -- g1
  table.insert(vertices, color[3]) -- b1
  table.insert(vertices, color[4]) -- a1

  table.insert(vertices, x + halfSize) -- x2
  table.insert(vertices, terrainHeight) -- y2 (terrain height)
  table.insert(vertices, z - halfSize) -- z2
  table.insert(vertices, color[1]) -- r2
  table.insert(vertices, color[2]) -- g2
  table.insert(vertices, color[3]) -- b2
  table.insert(vertices, color[4]) -- a2

  table.insert(vertices, x + halfSize) -- x3
  table.insert(vertices, terrainHeight) -- y3 (terrain height)
  table.insert(vertices, z + halfSize) -- z3
  table.insert(vertices, color[1]) -- r3
  table.insert(vertices, color[2]) -- g3
  table.insert(vertices, color[3]) -- b3
  table.insert(vertices, color[4]) -- a3

  -- Triangle 2
  table.insert(vertices, x - halfSize) -- x4
  table.insert(vertices, terrainHeight) -- y4 (terrain height)
  table.insert(vertices, z - halfSize) -- z4
  table.insert(vertices, color[1]) -- r4
  table.insert(vertices, color[2]) -- g4
  table.insert(vertices, color[3]) -- b4
  table.insert(vertices, color[4]) -- a4

  table.insert(vertices, x + halfSize) -- x5
  table.insert(vertices, terrainHeight) -- y5 (terrain height)
  table.insert(vertices, z + halfSize) -- z5
  table.insert(vertices, color[1]) -- r5
  table.insert(vertices, color[2]) -- g5
  table.insert(vertices, color[3]) -- b5
  table.insert(vertices, color[4]) -- a5

  table.insert(vertices, x - halfSize) -- x6
  table.insert(vertices, terrainHeight) -- y6 (terrain height)
  table.insert(vertices, z + halfSize) -- z6
  table.insert(vertices, color[1]) -- r6
  table.insert(vertices, color[2]) -- g6
  table.insert(vertices, color[3]) -- b6
  table.insert(vertices, color[4]) -- a6

  return vertices
end

local function updateVBO()
  if not damageAreas or not next(damageAreas) then
    return
  end

  local vertices = {}
  local areaCount = 0

  for _, area in pairs(damageAreas) do
    if area.x and area.z and area.efficiency then
      -- Check if area is within map bounds before creating vertices
      local halfSize = (area.tileSize or config.tileSize) / 2
      local mapSizeX = Game.mapSizeX
      local mapSizeZ = Game.mapSizeZ

      if area.x - halfSize >= 0 and area.x + halfSize <= mapSizeX and
         area.z - halfSize >= 0 and area.z + halfSize <= mapSizeZ then

        local color = getEfficiencyColor(area.efficiency)
        local tileVertices = createTileVertices(area.x, area.z, area.tileSize or config.tileSize, color)
        for _, vertex in ipairs(tileVertices) do
          table.insert(vertices, vertex)
        end
        areaCount = areaCount + 1
      end
    end
  end

  if #vertices == 0 then
    return
  end

  if vbo then
    vbo:Delete()
  end

  vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
  vbo:Define(
    #vertices / 7,
    {
      {id = 0, name = 'position', size = 3},
      {id = 1, name = 'color', size = 4}
    }
  )
  vbo:Upload(vertices)

  if vao then
    vao:Delete()
  end

  vao = gl.GetVAO()
  vao:AttachVertexBuffer(vbo)
end

local function drawTextLabels()
  if not config.showDamageValues and not config.showEfficiency and not config.showTopUnits and not config.showBottomUnits then
    return
  end

  local textCount = 0
  for _, area in pairs(damageAreas) do
    if area.x and area.z and area.efficiency then
      -- Use the same height as the tiles for consistent positioning
      local terrainHeight = (Spring.GetGroundHeight(area.x, area.z) or 0) + 15

      local text = ''
      if config.showEfficiency then
        text = string.format('E:%.2f', area.efficiency)
      end
      if config.showDamageValues then
        if text ~= '' then
          text = text .. '\n'
        end
        text = text .. string.format('D:%d\nT:%d', area.damageDealt or 0, area.damageTaken or 0)
      end

      -- Add top performing units
      if config.showTopUnits and area.top3Units and area.top3Units['1'] then
        if text ~= '' then
          text = text .. '\n'
        end
        text = text .. 'TOP:'
        for i, unit in pairs(area.top3Units) do
          if tonumber(i) <= 3 then -- Limit to top 3
            text = text .. string.format('\n%s:%.2f', unit.name, unit.efficiency)
          end
        end
      end

      -- Add bottom performing units
      if config.showBottomUnits and area.bottom3Units and area.bottom3Units['1'] then
        if text ~= '' then
          text = text .. '\n'
        end
        text = text .. 'BOT:'
        for i, unit in pairs(area.bottom3Units) do
          if tonumber(i) <= 3 then -- Limit to bottom 3
            text = text .. string.format('\n%s:%.2f', unit.name, unit.efficiency)
          end
        end
      end

      if text ~= '' then
        -- Set explicit text color to ensure visibility
        gl.Color(1.0, 1.0, 1.0, 0.7)
         gl.PushMatrix()
         gl.Translate(area.x-88, terrainHeight, area.z-82) -- Position much higher above the tile
         gl.Rotate(-90, 1, 0, 0) -- Lay flat
         gl.Text(text, 0, 0, 12, 'o')
         gl.PopMatrix()
        gl.Color(1.0, 1.0, 1.0, 1.0) -- Reset color
        textCount = textCount + 1
      end
    end
  end
end

function widget:Initialize()
  initShader()

  -- Create widget API
  WG['damageEfficiencyAreas'] = {}
  WG['damageEfficiencyAreas'].getConfig = function()
    return config
  end
  WG['damageEfficiencyAreas'].setConfig = function(newConfig)
    for key, value in pairs(newConfig) do
      if config[key] ~= nil then
        config[key] = value
      end
    end
  end

  -- Convenience functions for common toggles
  WG['damageEfficiencyAreas'].toggleTopUnits = function()
    config.showTopUnits = not config.showTopUnits
    Spring.Echo("Damage efficiency top units display: " .. (config.showTopUnits and "ON" or "OFF"))
  end
  WG['damageEfficiencyAreas'].toggleBottomUnits = function()
    config.showBottomUnits = not config.showBottomUnits
    Spring.Echo("Damage efficiency bottom units display: " .. (config.showBottomUnits and "ON" or "OFF"))
  end
end

function widget:Update()
  updateDamageAreas()
  updateVBO()
end

function widget:DrawWorldPreUnit()
  if not vao or not shader then
    return
  end

  gl.DepthTest(GL.LEQUAL)
  gl.DepthMask(false)
  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

  shader:Activate()
  vao:DrawArrays(GL.TRIANGLES)
  shader:Deactivate()

  gl.DepthTest(false)
  gl.DepthMask(true)
  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

function widget:DrawWorld()
  drawTextLabels()
end

function widget:Shutdown()
  if vbo then
    vbo:Delete()
    vbo = nil
  end
  if vao then
    vao:Delete()
    vao = nil
  end
  if shader then
    shader:Delete()
    shader = nil
  end
end

function widget:GetConfigData()
  return {
    config = config
  }
end

function widget:SetConfigData(data)
  if data.config then
    for key, value in pairs(data.config) do
      if config[key] ~= nil then
        config[key] = value
      end
    end
  end
end
