-- $Id: gui_attack_aoe.lua 3823 2009-01-19 23:40:49Z evil4zerggin $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local versionNumber = "v3.1c"

function widget:GetInfo()
  return {
    name      = "Attack AoE",
    desc      = versionNumber .. " Cursor indicator for area of effect and scatter when giving attack command.",
    author    = "Evil4Zerggin",
    date      = "26 September 2008",
    license   = "GNU LGPL, v2.1 or later",
    layer     = 1, 
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--config
--------------------------------------------------------------------------------
local numScatterPoints     = 32
local aoeColor             = {1, 0, 0, 1}
local aoeLineWidthMult     = 64
local scatterColor         = {1, 1, 0, 1}
local scatterLineWidthMult = 1024
local circleDivs           = 64
local minSpread            = 8 --weapons with this spread or less are ignored
local numAoECircles        = 9
local pointSizeMult        = 2048

--------------------------------------------------------------------------------
--vars
--------------------------------------------------------------------------------
local aoeDefInfo = {}
local dgunInfo = {}
local hasSelection = false
local aoeUnitDefID
local dgunUnitDefID
local aoeUnitID
local dgunUnitID
local circleList
local secondPart = 0
local mouseDistance = 1000

--------------------------------------------------------------------------------
--speedups
--------------------------------------------------------------------------------
local GetActiveCommand       = Spring.GetActiveCommand
local GetCameraPosition      = Spring.GetCameraPosition
local GetFeaturePosition     = Spring.GetFeaturePosition
local GetGroundHeight        = Spring.GetGroundHeight
local GetMouseState          = Spring.GetMouseState 
local GetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local GetUnitPosition        = Spring.GetUnitPosition
local GetUnitRadius          = Spring.GetUnitRadius
local GetUnitStates          = Spring.GetUnitStates
local TraceScreenRay         = Spring.TraceScreenRay
local CMD_ATTACK             = CMD.ATTACK
local CMD_DGUN               = CMD.MANUALFIRE
local g                      = Game.gravity
local GAME_SPEED             = 30
local g_f                    = g / GAME_SPEED / GAME_SPEED
local glBeginEnd             = gl.BeginEnd
local glCallList             = gl.CallList
local glCreateList           = gl.CreateList
local glColor                = gl.Color
local glDeleteList           = gl.DeleteList
local glDepthTest            = gl.DepthTest
local glDrawGroundCircle     = gl.DrawGroundCircle
local glLineWidth            = gl.LineWidth
local glPointSize            = gl.PointSize
local glPopMatrix            = gl.PopMatrix
local glPushMatrix           = gl.PushMatrix
local glRotate               = gl.Rotate
local glScale                = gl.Scale
local glTranslate            = gl.Translate
local glVertex               = gl.Vertex
local GL_LINES               = GL.LINES
local GL_LINE_LOOP           = GL.LINE_LOOP
local GL_POINTS              = GL.POINTS
local PI                     = math.pi
local atan                   = math.atan
local cos                    = math.cos
local sin                    = math.sin
local floor                  = math.floor
local max                    = math.max
local min                    = math.min
local sqrt                   = math.sqrt

--------------------------------------------------------------------------------
--utility functions
--------------------------------------------------------------------------------

local function ToBool(x)
  return x and x ~= 0 and x ~= "false"
end

local function Normalize(x, y, z)
  local mag = sqrt(x*x + y*y + z*z)
  if (mag == 0) 
    then return nil
    else return x/mag, y/mag, z/mag, mag
  end
end

local function VertexList(points)
  for i, point in pairs(points) do
    glVertex(point)
  end
end

local function GetMouseTargetPosition()
  local mx, my = GetMouseState()
  local mouseTargetType, mouseTarget = TraceScreenRay(mx, my)
  
  if (mouseTargetType == "ground") then
    return mouseTarget[1], mouseTarget[2], mouseTarget[3]
  elseif (mouseTargetType == "unit") then
    return GetUnitPosition(mouseTarget)
  elseif (mouseTargetType == "feature") then
    return GetFeaturePosition(mouseTarget)
  else
    return nil
  end
end

local function GetMouseDistance()
  local cx, cy, cz = GetCameraPosition()
  local mx, my, mz = GetMouseTargetPosition()
  if (not mx) then return nil end
  local dx = cx - mx
  local dy = cy - my
  local dz = cz - mz
  return sqrt(dx*dx + dy*dy + dz*dz)
end

local function UnitCircleVertices()
  for i = 1, circleDivs do
    local theta = 2 * PI * i / circleDivs
    glVertex(cos(theta), 0, sin(theta))
  end
end

local function DrawUnitCircle()
  glBeginEnd(GL_LINE_LOOP, UnitCircleVertices)
end

local function DrawCircle(x, y, z, radius)
  glPushMatrix()
  glTranslate(x, y, z)
  glScale(radius, radius, radius)
  
  glCallList(circleList)
  
  glPopMatrix()
end

local function GetSecondPart(offset)
  local result = secondPart + (offset or 0)
  return result - floor(result)
end

--------------------------------------------------------------------------------
--initialization
--------------------------------------------------------------------------------

local function SetupUnitDef(unitDefID, unitDef)
  if (not unitDef.weapons) then return end
  
  local maxSpread = minSpread
  local maxWeaponDef
  
  for _, weapon in ipairs(unitDef.weapons) do
    if (weapon.weaponDef) then
      local weaponDef = WeaponDefs[weapon.weaponDef]
      if (weaponDef) then
        if (weaponDef.type == "DGun") then
          dgunInfo[unitDefID] = {range = weaponDef.range, aoe = weaponDef.damageAreaOfEffect}
        elseif (weaponDef.canAttackGround
                and not weaponDef.isShield 
                and not ToBool(weaponDef.interceptor)
                and (weaponDef.damageAreaOfEffect > maxSpread or weaponDef.range * (weaponDef.accuracy + weaponDef.sprayAngle) > maxSpread )
                and not string.find(weaponDef.name, "flak")) then
          maxSpread = max(weaponDef.damageAreaOfEffect, weaponDef.range * (weaponDef.accuracy + weaponDef.sprayAngle))
          maxWeaponDef = weaponDef
        end
      end
    end
  end
  
  if (not maxWeaponDef) then return end
  
  local weaponType = maxWeaponDef.type
  local scatter = maxWeaponDef.accuracy + maxWeaponDef.sprayAngle
  local aoe = maxWeaponDef.damageAreaOfEffect
  local cost = unitDef.cost
  local mobile = unitDef.speed > 0
  local waterWeapon = maxWeaponDef.waterWeapon
  local ee = maxWeaponDef.edgeEffectiveness
  
  if (maxWeaponDef.cylinderTargetting >= 100) then
    aoeDefInfo[unitDefID] = {type = "orbital", scatter = scatter}
  elseif (weaponType == "Cannon") then
    aoeDefInfo[unitDefID] = {type = "ballistic", scatter = scatter, v = maxWeaponDef.maxVelocity, range = maxWeaponDef.range}
  elseif (weaponType == "MissileLauncher") then
    local turnRate = 0
    if (maxWeaponDef.tracks) then
      turnRate = maxWeaponDef.turnRate
    end
    if (maxWeaponDef.wobble > turnRate * 1.4) then
      scatter = (maxWeaponDef.wobble - maxWeaponDef.turnRate) * maxWeaponDef.maxVelocity * 16
      local rangeScatter = (8 * maxWeaponDef.wobble - maxWeaponDef.turnRate)
      aoeDefInfo[unitDefID] = {type = "wobble", scatter = scatter, rangeScatter = rangeScatter, range = maxWeaponDef.range}
    elseif (maxWeaponDef.wobble > turnRate) then
      scatter = (maxWeaponDef.wobble - maxWeaponDef.turnRate) * maxWeaponDef.maxVelocity * 16
      aoeDefInfo[unitDefID] = {type = "wobble", scatter = scatter}
    elseif (maxWeaponDef.tracks) then
      aoeDefInfo[unitDefID] = {type = "tracking"}
    else
      aoeDefInfo[unitDefID] = {type = "direct", scatter = scatter, range = maxWeaponDef.range}
    end
  elseif (weaponType == "AircraftBomb") then
    aoeDefInfo[unitDefID] = {type = "dropped", scatter = scatter, v = unitDef.speed, h = unitDef.wantedHeight, salvoSize = maxWeaponDef.salvoSize, salvoDelay = maxWeaponDef.salvoDelay}
  elseif (weaponType == "StarburstLauncher") then
    if (maxWeaponDef.tracks) then
      aoeDefInfo[unitDefID] = {type = "tracking"}
    else
      aoeDefInfo[unitDefID] = {type = "cruise"}
    end
  elseif (weaponType == "TorpedoLauncher") then
    if (maxWeaponDef.tracks) then
      aoeDefInfo[unitDefID] = {type = "tracking"}
    else
      aoeDefInfo[unitDefID] = {type = "direct", scatter = scatter, range = maxWeaponDef.range}
    end
  elseif (weaponType == "Flame" ) then
    aoeDefInfo[unitDefID] = {type = "noexplode", range = maxWeaponDef.range}
  else
    aoeDefInfo[unitDefID] = {type = "direct", scatter = scatter, range = maxWeaponDef.range}
  end
  
  aoeDefInfo[unitDefID].aoe = aoe
  aoeDefInfo[unitDefID].cost = cost
  aoeDefInfo[unitDefID].mobile = mobile
  aoeDefInfo[unitDefID].waterWeapon = waterWeapon
  aoeDefInfo[unitDefID].ee = ee
end

local function SetupDisplayLists()
  circleList = glCreateList(DrawUnitCircle)
end

local function DeleteDisplayLists()
  glDeleteList(circleList)
end

--------------------------------------------------------------------------------
--updates
--------------------------------------------------------------------------------
local function GetRepUnitID(unitIDs)
  return unitIDs[1]
end

local function UpdateSelection()
  local sel = GetSelectedUnitsSorted()
    
  local maxCost = 0
  dgunUnitDefID = nil
  aoeUnitDefID = nil
  dgunUnitID = nil
  aoeUnitID = nil
  hasSelection = false
  
  for unitDefID, unitIDs in pairs(sel) do
    if (dgunInfo[unitDefID]) then 
      dgunUnitDefID = unitDefID
      dgunUnitID = unitIDs[1]
      hasSelection = true
    end
  
    if (aoeDefInfo[unitDefID]) then
      local currCost = UnitDefs[unitDefID].cost * #unitIDs
      if (currCost > maxCost) then
        maxCost = currCost
        aoeUnitDefID = unitDefID
        aoeUnitID = GetRepUnitID(unitIDs)
        hasSelection = true
      end
    end
  end
end

--------------------------------------------------------------------------------
--aoe
--------------------------------------------------------------------------------

local function DrawAoE(tx, ty, tz, aoe, ee, alphaMult, offset)
  glLineWidth(aoeLineWidthMult * aoe / mouseDistance)
  
  for i=1,numAoECircles do
    local proportion = i / (numAoECircles + 1)
    local radius = aoe * proportion
    local alpha = aoeColor[4] * (1 - proportion) / (1 - proportion * ee) * (1 - GetSecondPart(offset or 0)) * (alphaMult or 1)
    glColor(aoeColor[1], aoeColor[2], aoeColor[3], alpha)
    DrawCircle(tx, ty, tz, radius)
  end

  glColor(1,1,1,1)
  glLineWidth(1)
end

--------------------------------------------------------------------------------
--dgun/noexplode
--------------------------------------------------------------------------------
local function DrawNoExplode(aoe, fx, fy, fz, tx, ty, tz, range)
  
  local dx = tx - fx
  local dy = ty - fy
  local dz = tz - fz
  
  local bx, by, bz, dist = Normalize(dx, dy, dz)
  
  if (not bx or dist > range) then return end
  
  local br = sqrt(bx*bx + bz*bz)
  
  local wx = -aoe * bz / br
  local wz = aoe * bx / br
  
  local ex = range * bx / br
  local ez = range * bz / br
  
  local vertices = {{fx + wx, fy, fz + wz}, {fx + ex + wx, ty, fz + ez + wz},
                    {fx - wx, fy, fz - wz}, {fx + ex - wx, ty, fz + ez - wz}}
  local alpha = (1 - GetSecondPart()) * aoeColor[4]
  glColor(aoeColor[1], aoeColor[2], aoeColor[3], alpha)
  glLineWidth(scatterLineWidthMult / mouseDistance)
  
  glBeginEnd(GL_LINES, VertexList, vertices)

  glColor(1,1,1,1)
  glLineWidth(1)
end

--------------------------------------------------------------------------------
--ballistics
--------------------------------------------------------------------------------

local function GetBallisticVector(v, dx, dy, dz, trajectory, range)
  local dr_sq = dx*dx + dz*dz
  local dr = sqrt(dr_sq)
  
  if (dr > range) then return nil end
  
  local d_sq = dr_sq + dy*dy
  
  if (d_sq == 0) then
    return 0, v * trajectory, 0
  end
  
  local root1 = v*v*v*v - 2*v*v*g*dy - g*g*dr_sq
  if (root1 < 0) then return nil end
  
  local root2 = 2*dr_sq*d_sq*(v*v - g*dy - trajectory*sqrt(root1))
  
  if (root2 < 0) then return nil end
  
  local vr = sqrt(root2)/(2*d_sq)
  local vy
  
  if (r == 0 or vr == 0) 
    then vy = v
    else vy = vr*dy/dr + dr*g/(2*vr)
  end
  
  local bx = dx*vr/dr
  local bz = dz*vr/dr
  local by = vy
  return Normalize(bx, by, bz)
end

local function GetBallisticImpactPoint(v, fx, fy, fz, bx, by, bz)
  local v_f = v / GAME_SPEED
  local vx_f = bx * v_f
  local vy_f = by * v_f
  local vz_f = bz * v_f
  local px = fx
  local py = fy
  local pz = fz
  
  local ttl = 4 * v_f / g_f
  
  for i=1,ttl do
    px = px + vx_f
    py = py + vy_f
    pz = pz + vz_f
    vy_f = vy_f - g_f
    
    local gwh = max(GetGroundHeight(px, pz), 0)
    
    if (py < gwh) then
      local interpolate = min((py - gwh) / vy_f, 1)
      local x = px - interpolate * vx_f
      local z = pz - interpolate * vz_f
      return {x, max(GetGroundHeight(x, z), 0), z}
    end
  end
  
  return {px, py, pz}
end

--v: weaponvelocity
--trajectory: +1 for high, -1 for low
local function DrawBallisticScatter(scatter, v, fx, fy, fz, tx, ty, tz, trajectory, range)
  if (scatter == 0) then return end
  local dx = tx - fx
  local dy = ty - fy
  local dz = tz - fz
  if (dx == 0 and dz == 0) then return end
  
  local bx, by, bz = GetBallisticVector(v, dx, dy, dz, trajectory, range)
  
  --don't draw anything if out of range
  if (not bx) then return end
  
  local br = sqrt(bx*bx + bz*bz)
  
  --bars
  local rx = dx / br
  local rz = dz / br
  local wx = -scatter * rz
  local wz = scatter * rx
  local barLength = sqrt(wx*wx + wz*wz) --length of bars
  local barX = 0.5 * barLength * bx / br
  local barZ = 0.5 * barLength * bz / br
  local sx = tx - barX
  local sz = tz - barZ
  local lx = tx + barX
  local lz = tz + barZ
  local wsx = -scatter * (rz - barZ)
  local wsz = scatter * (rx - barX)
  local wlx = -scatter * (rz + barZ)
  local wlz = scatter * (rx + barX)
  
  local bars = {{tx + wx, ty, tz + wz}, {tx - wx, ty, tz - wz},
                {sx + wsx, ty, sz + wsz}, {lx + wlx, ty, lz + wlz},
                {sx - wsx, ty, sz - wsz}, {lx - wlx, ty, lz - wlz}}
  
  local scatterDiv = scatter / numScatterPoints
  local vertices = {}
  
  --trace impact points
  for i = -numScatterPoints, numScatterPoints do
    local currScatter = i * scatterDiv
    local currScatterCos = sqrt(1 - currScatter * currScatter)
    local rMult = currScatterCos - by * currScatter / br
    local bx_c = bx * rMult
    local by_c = by * currScatterCos + br * currScatter
    local bz_c = bz * rMult
    
    vertices[i+numScatterPoints+1] = GetBallisticImpactPoint(v, fx, fy, fz, bx_c, by_c, bz_c)
  end
  
  glLineWidth(scatterLineWidthMult / mouseDistance)
  glPointSize(pointSizeMult / mouseDistance)
  glColor(scatterColor)
  glDepthTest(false)
  glBeginEnd(GL_LINES, VertexList, bars)
  glBeginEnd(GL_POINTS, VertexList, vertices)
  glDepthTest(true)
  glColor(1,1,1,1)
  glPointSize(1)
  glLineWidth(1)
end

--------------------------------------------------------------------------------
--wobble
--------------------------------------------------------------------------------
local function DrawWobbleScatter(scatter, fx, fy, fz, tx, ty, tz, rangeScatter, range)
  local dx = tx - fx
  local dy = ty - fy
  local dz = tz - fz
  
  local bx, by, bz, d = Normalize(dx, dy, dz)
  
  glColor(scatterColor)
  glLineWidth(scatterLineWidthMult / mouseDistance)
  if d and range then
    if d <= range then
      DrawCircle(tx, ty, tz, rangeScatter * d + scatter)
    end
  else
    DrawCircle(tx, ty, tz, scatter)
  end
  glColor(1,1,1,1)
  glLineWidth(1)
end

--------------------------------------------------------------------------------
--direct
--------------------------------------------------------------------------------
local function DrawDirectScatter(scatter, fx, fy, fz, tx, ty, tz, range, unitRadius)
  local dx = tx - fx
  local dy = ty - fy
  local dz = tz - fz
  
  local bx, by, bz, d = Normalize(dx, dy, dz)
  
  if (not bx or d == 0 or d > range) then return end
  
  local ux = bx * unitRadius / sqrt(1 - by*by)
  local uz = bz * unitRadius / sqrt(1 - by*by)
  
  local cx = -scatter * uz
  local cz = scatter * ux
  local wx = -scatter * dz / sqrt(1 - by*by)
  local wz = scatter * dx / sqrt(1 - by*by)
  
  local vertices = {{fx + ux + cx, fy, fz + uz + cz}, {tx + wx, ty, tz + wz},
                    {fx + ux - cx, fy, fz + uz - cz}, {tx - wx, ty, tz - wz}}
  
  glColor(scatterColor)
  glLineWidth(scatterLineWidthMult / mouseDistance)
  glBeginEnd(GL_LINES, VertexList, vertices)
  glColor(1,1,1,1)
  glLineWidth(1)
end

--------------------------------------------------------------------------------
--dropped
--------------------------------------------------------------------------------
local function DrawDroppedScatter(aoe, ee, scatter, v, fx, fy, fz, tx, ty, tz, salvoSize, salvoDelay)
  local dx = tx - fx
  local dz = tz - fz
  
  local bx, _, bz = Normalize(dx, 0, dz)
  
  if (not bx) then return end
  
  local vertices = {}
  local currScatter = scatter * v * sqrt(2*fy/g)
  local alphaMult = min(v * salvoDelay / aoe, 1)
  
  for i=1,salvoSize do
    local delay = salvoDelay * (i - (salvoSize + 1) / 2)
    local dist = v * delay
    local px_c = dist * bx + tx
    local pz_c = dist * bz + tz
    local py_c = max(GetGroundHeight(px_c, pz_c), 0)
    
    DrawAoE(px_c, py_c, pz_c, aoe, ee, alphaMult, -delay)
    glColor(scatterColor[1], scatterColor[2], scatterColor[3], scatterColor[4] * alphaMult)
    glLineWidth(scatterLineWidthMult / mouseDistance)
    DrawCircle(px_c, py_c, pz_c, currScatter)
  end
  glColor(1,1,1,1)
  glLineWidth(1)
end

--------------------------------------------------------------------------------
--orbital
--------------------------------------------------------------------------------
local function DrawOrbitalScatter(scatter, tx, ty, tz)
  glColor(scatterColor)
  glLineWidth(scatterLineWidthMult / mouseDistance)
  DrawCircle(tx, ty, tz, scatter)
  glColor(1,1,1,1)
  glLineWidth(1)
end
--------------------------------------------------------------------------------
--callins
--------------------------------------------------------------------------------

function widget:MousePress()
  UpdateSelection()
end

function widget:KeyPress()
  UpdateSelection()
end

function widget:Initialize()
  for unitDefID, unitDef in pairs(UnitDefs) do
    SetupUnitDef(unitDefID, unitDef)
  end
  SetupDisplayLists()
end

function widget:Shutdown()
  DeleteDisplayLists()
end

function widget:DrawWorld()
 
  if not hasSelection then return end
  local _, cmd, _ = GetActiveCommand()
  
  if (cmd == CMD_DGUN and dgunUnitDefID) then
    mouseDistance = GetMouseDistance() or 1000
    local tx, ty, tz = GetMouseTargetPosition()
    if (not tx) then return end
    local info = dgunInfo[dgunUnitDefID]
    local fx, fy, fz = GetUnitPosition(dgunUnitID)   
    if (not fx) then return end
    local angle = math.atan2(fx-tx,fz-tz) + (math.pi/2.1)
    local dx = fx+(sin(angle)*13)
    local dz = fz+(cos(angle)*13)
    local angle2 = math.atan2(dx-tx,dz-tz)
    DrawNoExplode(info.aoe, dx, fy, dz, dx-(sin(angle2)*125), ty,dz-(cos(angle2)*125), info.range)
    glColor(1, 0, 0, 0.75)
    glLineWidth(1)
    glDrawGroundCircle(dx, fy, dz, info.range, circleDivs)
    glColor(1,1,1,1)
    return
  end
  
  if (cmd ~= CMD_ATTACK or not aoeUnitDefID) then 
    UpdateSelection()
    return 
  end
  
  mouseDistance = GetMouseDistance() or 1000
  local tx, ty, tz = GetMouseTargetPosition()
  if (not tx) then return end
  
  local info = aoeDefInfo[aoeUnitDefID]
  
  local fx, fy, fz = GetUnitPosition(aoeUnitID)
  if (not fx) then return end
  if (not info.mobile) then fy = fy + GetUnitRadius(aoeUnitID) end
  
  if (not info.waterWeapon) then ty = max(0, ty) end
  
  local weaponType = info.type
  
  if (weaponType == "ballistic") then
    local states = GetUnitStates(aoeUnitID)
    local trajectory
    if (states.trajectory) then
      trajectory = 1
    else
      trajectory = -1
    end
    DrawAoE(tx, ty, tz, info.aoe, info.ee)
    DrawBallisticScatter(info.scatter, info.v, fx, fy, fz, tx, ty, tz, trajectory, info.range)
  elseif (weaponType == "noexplode") then
    DrawNoExplode(info.aoe, fx, fy, fz, tx, ty, tz, info.range)
  elseif (weaponType == "tracking") then
    DrawAoE(tx, ty, tz, info.aoe, info.ee)
  elseif (weaponType == "direct") then
    DrawAoE(tx, ty, tz, info.aoe, info.ee)
    DrawDirectScatter(info.scatter, fx, fy, fz, tx, ty, tz, info.range, GetUnitRadius(aoeUnitID))
  elseif (weaponType == "dropped") then
    DrawDroppedScatter(info.aoe, info.ee, info.scatter, info.v, fx, info.h, fz, tx, ty, tz, info.salvoSize, info.salvoDelay)
  elseif (weaponType == "wobble") then
    DrawAoE(tx, ty, tz, info.aoe, info.ee)
    DrawWobbleScatter(info.scatter, fx, fy, fz, tx, ty, tz, info.rangeScatter, info.range)
  elseif (weaponType == "orbital") then
    DrawAoE(tx, ty, tz, info.aoe, info.ee)
    DrawOrbitalScatter(info.scatter, tx, ty, tz)
  else
    DrawAoE(tx, ty, tz, info.aoe, info.ee)
  end
end

function widget:SelectionChanged(sel)
  UpdateSelection()
  widgetHandler:RemoveCallIn("MousePress")
  widgetHandler:RemoveCallIn("KeyPress")
end

function widget:Update(dt)
  secondPart = secondPart + dt
  secondPart = secondPart - floor(secondPart)
end
