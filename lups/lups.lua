-- $Id: lups.lua 4099 2009-03-16 05:18:45Z jk $
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    api_gfx_lups.lua
--  brief:   Lua Particle System
--  authors: jK
--  last updated: Jan. 2008
--
--  Copyright (C) 2007,2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------


local function GetInfo()
  return {
    name      = "Lups",
    desc      = "Lua Particle System",
    author    = "jK",
    date      = "Jan. 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 1000,
    api       = true,
    enabled   = true
  }
end


--// FIXME
-- 1. at los handling (inRadar,alwaysVisible, etc.)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// Error Log Handling

PRIO_MAJOR = 0
PRIO_ERROR = 1
PRIO_LESS  = 2

local errorLog = {}
local printErrorsAbove = PRIO_MAJOR
function print(priority,...)
  local errorMsg = ""
  for i=1,select('#',...) do
    errorMsg = errorMsg .. select(i,...)
  end
  errorLog[#errorLog+1] = {priority=priority,message=errorMsg}

  if (priority<=printErrorsAbove) then
    Spring.Echo(...)
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// locals

local push = table.insert
local pop  = table.remove
local StrToLower = string.lower

local pairs  = pairs
local ipairs = ipairs
local next   = next

local spGetUnitRadius        = Spring.GetUnitRadius
local spIsUnitVisible        = Spring.IsUnitVisible
local spIsSphereInView       = Spring.IsSphereInView
local spGetUnitLosState      = Spring.GetUnitLosState
local spGetUnitViewPosition  = Spring.GetUnitViewPosition
local spGetUnitDirection     = Spring.GetUnitDirection
local spGetHeadingFromVector = Spring.GetHeadingFromVector
local spGetUnitIsActive      = Spring.GetUnitIsActive
local spGetGameFrame         = Spring.GetGameFrame
local spGetFrameTimeOffset   = Spring.GetFrameTimeOffset
local spGetUnitPieceList     = Spring.GetUnitPieceList
local spGetSpectatingState   = Spring.GetSpectatingState
local spGetLocalAllyTeamID   = Spring.GetLocalAllyTeamID
local scGetReadAllyTeam      = Script.GetReadAllyTeam
local spGetUnitPieceMap      = Spring.GetUnitPieceMap
local spValidUnitID          = Spring.ValidUnitID
local spGetUnitRulesParam    = Spring.GetUnitRulesParam

local glUnitPieceMatrix = gl.UnitPieceMatrix
local glPushMatrix      = gl.PushMatrix
local glPopMatrix       = gl.PopMatrix
local glTranslate       = gl.Translate
local glRotate          = gl.Rotate
local glScale           = gl.Scale
local glBlending        = gl.Blending
local glAlphaTest       = gl.AlphaTest
local glDepthTest       = gl.DepthTest
local glDepthMask       = gl.DepthMask
local glUnitMultMatrix  = gl.UnitMultMatrix
local glUnitPieceMultMatrix = gl.UnitPieceMultMatrix

local GL_GREATER = GL.GREATER
local GL_ONE     = GL.ONE
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA


--// spring 76b1 compa

if (not Spring.GetUnitPieceMap) then
  spGetUnitPieceMap = function (unitID)
    local pieceMap = {}
    for piecenum,piecename in pairs(spGetUnitPieceList(unitID)) do
      pieceMap[piecename] = piecenum
    end
    return pieceMap
  end
end

--// spring 76b1 compa
if (not Spring.IsPosInLos) then
  local spGetPositionLosState = Spring.GetPositionLosState
  Spring.IsPosInLos    = function(...) return select(2,spGetPositionLosState(...)); end
  Spring.IsPosInAirLos = function(...) return select(3,spGetPositionLosState(...)); end
  Spring.IsPosInRadar  = function(...) return select(4,spGetPositionLosState(...)); end
end

--// spring 75b2 compa

if (not gl.UnitMultMatrix) then
  glUnitMultMatrix = function (unitID)
    local x,y,z    = spGetUnitViewPosition(unitID)
    local dx,dy,dz = spGetUnitDirection(unitID)
    local h = spGetHeadingFromVector(dx,dz)
    glTranslate(x,y,z)
    glRotate(h/360*2, 0, 1, 0)
  end
end

if (not gl.UnitPieceMultMatrix) then
  glUnitPieceMultMatrix = function (unitID,piece)
    glScale(1,1,-1)
    glUnitPieceMatrix(unitID,piece)
    glScale(1,1,-1)
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// hardware capabilities
local GL_VENDOR   = 0x1F00
local GL_RENDERER = 0x1F01
local GL_VERSION  = 0x1F02

local glVendor   = gl.GetString(GL_VENDOR)
local glRenderer = (gl.GetString(GL_RENDERER)):lower()

local function DetectCard(vendor,renderer)
  isNvidia  = (vendor:find("NVIDIA"))
  isATI     = (vendor:find("ATI "))
  isMS      = (vendor:find("Microsoft"))
  isIntel   = (vendor:find("Intel"))

  renderer  = renderer:lower()

  NVseries  = ((isNvidia)and(
                 (renderer:find("quadro [56]%d%d%d") and 11) or  --// Quadro series
                 (renderer:find("quadro cx") and 10) or
                 (renderer:find("quadro fx 5[678]%d%d") and 10) or
                 (renderer:find("quadro fx 5[234]%d%d") and 8) or
                 (renderer:find("quadro fx [1-4]%d%d%d") and 8) or
                 (renderer:find(" gf[xs]* 4%d%d") and 11) or  --// Fermi
                 (renderer:find(" g[txs]* %d%d%d") and 10) or
                 (renderer:find(" 9") and 9) or
                 (renderer:find(" 8") and 8) or
                 (renderer:find(" 7") and 7) or
                 (renderer:find(" 6") and 6) or
                 (renderer:find(" 5") and 5) or
                 (renderer:find(" 4") and 4) or
                 (renderer:find(" 3") and 3) or 
                 (renderer:find(" 2") and 2) or math.huge
               )) or 0

  ATIseries = ((isATI)and(
                (renderer:find("radeon hd") and 3)or
                (renderer:find("radeon x") and 2) or
                (renderer:find("radeon 9") and 1) or 0
              )) or 0

  canCTT = (gl.CopyToTexture ~= nil)

  --// old cards are capable to use CTT, but their performance is too bad
  canCTT = (canCTT) and ((not isNvidia)or(NVseries>=6))
  canCTT = (canCTT) and ((not isATI)   or(ATIseries>=2))
end

isNvidia  = false
isATI     = false
isMS      = false
isIntel   = false
NVseries  = false
ATIseries = false
canCTT    = false
canFBO    = (gl.DeleteTextureFBO ~= nil)
canRTT    = (gl.RenderToTexture  ~= nil)
canShader = (gl.CreateShader     ~= nil)
canDistortions = false --// check Initialize()

DetectCard(glVendor,glRenderer)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// widget/gadget handling
local handler = (widget and widgetHandler)or(gadgetHandler)
local GG      = (widget and WG)or(GG)
local VFSMODE = (widget and VFS.RAW_FIRST)or(VFS.ZIP_ONLY)

--// locations
local LUPS_LOCATION    = 'lups/'
local PCLASSES_DIRNAME = LUPS_LOCATION .. 'ParticleClasses/'
local HEADERS_DIRNAME  = LUPS_LOCATION .. 'headers/'

--// helpers
VFS.Include(LUPS_LOCATION .. 'loadconfig.lua',nil,VFSMODE)

--// load some headers
VFS.Include(HEADERS_DIRNAME .. 'general.lua',nil,VFSMODE)
VFS.Include(HEADERS_DIRNAME .. 'mathenv.lua',nil,VFSMODE)
VFS.Include(HEADERS_DIRNAME .. 'figures.lua',nil,VFSMODE)
VFS.Include(HEADERS_DIRNAME .. 'vectors.lua',nil,VFSMODE)
VFS.Include(HEADERS_DIRNAME .. 'hsl.lua',nil,VFSMODE)

--// load binary insert library
VFS.Include(HEADERS_DIRNAME .. 'tablebin.lua')
local flayer_comp = function( partA,partB )
  return ( partA==partB )or
         ( (partA.layer==partB.layer)and((partA.unit or -1)<(partB.unit or -1)) )or
         ( partA.layer<partB.layer )
end

--// workaround for broken UnitDraw() callin
local nilDispList


--// global function (fx classes can use it) for easier access to Lups.cfg
function GetLupsSetting(key, default)
  local value = LupsConfig[key]
  if (value~=nil) then
    return value
  else
    return default
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// some global vars (so the effects can use them)
vsx, vsy, vpx, vpy = Spring.GetViewGeometry() --// screen pos & view pos (view pos only unequal zero if dualscreen+minimapOnTheLeft)
LocalAllyTeamID = 0
thisGameFrame   = 0
frameOffset     = 0
LupsConfig      = {}

local noDrawUnits = {}
function SetUnitLuaDraw(unitID,draw)
  if (draw) then
    noDrawUnits[unitID] = (noDrawUnits[unitID] or 0) + 1
    if (noDrawUnits[unitID]==1) then
      --if (Game.version=="0.76b1") then
        Spring.UnitRendering.SetLODCount(unitID,1)
        for pieceID,pieceName in pairs(Spring.GetUnitPieceList(unitID) or {}) do
          if (pieceID~="n") then
            Spring.UnitRendering.SetPieceList(unitID,1,pieceID,nilDispList)
          end
        end
      --else
      --  Spring.UnitRendering.SetUnitLuaDraw(unitID,true)
      --end
    end
  else
    noDrawUnits[unitID] = (noDrawUnits[unitID] or 0) - 1
    if (noDrawUnits[unitID]==0) then
      --if (Game.version=="0.76b1") then
        for pieceID,pieceName in pairs(Spring.GetUnitPieceList(unitID) or {}) do
          if (pieceID~="n") then
            Spring.UnitRendering.SetPieceList(unitID,1,pieceID)
          end
        end
        Spring.UnitRendering.SetLODCount(unitID,0)
      --else
      --  Spring.UnitRendering.SetUnitLuaDraw(unitID,false)
      --end
      noDrawUnits[unitID] = nil
    end
  end
end

local function DrawUnit(_,unitID,drawMode)
--[[
 drawMode:
  notDrawing     = 0,
  normalDraw     = 1,
  shadowDraw     = 2,
  reflectionDraw = 3,
  refractionDraw = 4
--]]

  if (drawMode==1)and(noDrawUnits[unitID]) then
    return true
  end
  return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local oldVsx,oldVsy = vsx-1,vsy-1

--// load particle classes
local fxClasses = {}
local DistortionClass

local files = VFS.DirList(PCLASSES_DIRNAME, "*.lua",VFSMODE)
for _,filename in ipairs(files) do
  local Class = VFS.Include(filename,nil,VFSMODE)
  if (Class) then
    if (Class.GetInfo) then
      Class.pi = Class.GetInfo()
      local sClassName = string.lower(Class.pi.name)
      if (fxClasses[sClassName]) then
        print(PRIO_LESS,'LUPS: duplicated particle class name "' .. sClassName .. '"')
      else
        fxClasses[sClassName] = Class
      end
    else
      print(PRIO_ERROR,'LUPS: "' .. Class .. '" is missing GetInfo() ')
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// saves all particles
particles = {}
local particles = particles 
local particlesCount = 0
local fxToDestroy = {}

local RenderSequence = {}  --// mult-dim table with: [layer][partClass][unitID][fx]
local effectsInDelay = {}  --// fxs which use the delay tag, and waiting for their spawn
local partIDCount = 0  --// increasing ID used to identify the particles

--[[
local function DebugPieces(unit,piecenum,level)
  local piece = Spring.GetUnitPieceInfo(unit,piecenum)
  Spring.Echo( string.rep(" ", level) .. "->" .. piece.name .. " (" .. piecenum .. ")")
  for _,pieceChildName in ipairs(piece.children) do
    local pieceNum = spGetUnitPieceMap(unit)[pieceChildName]
    DebugPieces(unit,pieceNum,level+1)
  end
end
--]]


--// the id param is internal don't use it!
function AddParticles(Class,Options   ,__id)
  if (not Options) then
    print(PRIO_LESS,'LUPS->AddFX: no options given');
    return -1;
  end

  if (Options.delay and Options.delay~=0) then
    partIDCount = partIDCount+1
    newOptions = {}; CopyTable(newOptions,Options); newOptions.delay=nil
    effectsInDelay[#effectsInDelay+1] = {frame=thisGameFrame+Options.delay, class=Class, options=newOptions, id=partIDCount};
    return partIDCount
  end

  Class = StrToLower(Class)
  local particleClass = fxClasses[Class]

  if (not particleClass) then
    print(PRIO_LESS,'LUPS->AddFX: couldn\'t find a particle class named "' .. Class .. '"');
    return -1;
  end

  if (Options.unit)and(not spValidUnitID(Options.unit)) then
    print(PRIO_LESS,'LUPS->AddFX: unit is already dead/invalid "' .. Class .. '"');
    return -1;
  end

  --// piecename to piecenum conversion (spring >=76b1 only!)
  if (Options.unit and Options.piece) then
    Options.piecenum = spGetUnitPieceMap(Options.unit)[Options.piece]
    if (not Options.piecenum) then
      local udid = Spring.GetUnitDefID(Options.unit)
      if (not udid) then
        print(PRIO_LESS,"LUPS->AddFX:wrong unitID")
      else
        print(PRIO_ERROR,"LUPS->AddFX:wrong unitpiece " .. Options.piece .. "(" .. UnitDefs[udid].name .. ")")
      end
      return -1;
    end
  end

  --Spring.Echo("-------------")
  --DebugPieces(Options.unit,1,0)


  local newParticles,reusedFxID = particleClass.Create(Options)
  if (newParticles) then
    particlesCount = particlesCount + 1;

    if (__id) then
      newParticles.id = __id
    else
      partIDCount = partIDCount+1
      newParticles.id = partIDCount
    end
    particles[ newParticles.id ] = newParticles

    local space = ((not newParticles.worldspace) and newParticles.unit) or (-1)
    local fxTable = CreateSubTables(RenderSequence,{newParticles.layer,particleClass,space})
    newParticles.fxTable = fxTable
    fxTable[#fxTable+1] = newParticles

    return newParticles.id;
  else
    if (reusedFxID) then
      return reusedFxID;
    else
      if (newParticles~=false) then
        print(PRIO_LESS,"LUPS->AddFX:FX creation failed");
      end
      return -1;
    end
  end
end


function AddParticlesArray(array)
  local class = ""
  for i=1,#array do
    local fxSettings = array[i]
    class = fxSettings.class
    fxSettings.class = nil
    AddParticles(class,fxSettings)
  end
end


function RemoveParticles(particlesID)
  local fx = particles[particlesID]
  if (fx) then
    if (type(fx.fxTable)=="table") then
      for j,w in pairs(fx.fxTable) do
        if (w.id==particlesID) then
          pop(fx.fxTable,j)
        end
      end
    end
    fxToDestroy[#fxToDestroy+1] = fx
    particles[particlesID] = nil
    particlesCount = particlesCount-1;
    return
  else
    local status,err = pcall(function()
--//FIXME
      for i=1,#effectsInDelay do
        if (effectsInDelay[i].id==particlesID) then
          table.remove(effectsInDelay,i)
          return
        end
      end
--//
    end)

    if (not status) then
      Spring.Echo("Error (Lups) - "..(#effectsInDelay).." :"..err)
      for i=1,#effectsInDelay do
        Spring.Echo("->",effectsInDelay[i],type(effectsInDelay[i]))
      end
      effectsInDelay = {}
    end
  end
end

function GetStats()
  local count   = particlesCount
  local effects = {}
  local layers  = 0

  for i=-50,50 do
    if (RenderSequence[i]) then
      local layer = RenderSequence[i];

      if (next(layer or {})) then layers=layers+1 end

      for partClass,Units in pairs(layer) do
        if (not effects[partClass.pi.name]) then
          effects[partClass.pi.name] = {0,0} --//[1]:=fx count  [2]:=part count
        end
        for unitID,UnitEffects in pairs(Units) do
          for _,fx in pairs(UnitEffects) do
            effects[partClass.pi.name][1] = effects[partClass.pi.name][1] + 1
            effects[partClass.pi.name][2] = effects[partClass.pi.name][2] + (fx.count or 0)
            --count = count+1
          end
        end
      end
    end
  end

  return count,layers,effects
end


function HasParticleClass(ClassName)
  local Class = StrToLower(ClassName)
  return (fxClasses[Class] and true)or(false)
end


function GetErrorLog(minPriority)
  if (minPriority) then
    local log = ""
    for i=1,#errorLog do
      if (errorLog[i].priority<=minPriority) then
        log = log .. errorLog[i].message .. "\n"
      end
    end
    if (log~="") then
      local sysinfo = "Vendor:" .. glVendor ..
                      "\nRenderer:" .. glRenderer ..
                      "\nNVseries:" .. NVseries ..
                      (((isATI)and("\nisATI: true"))or("")) ..
                      (((isMS)and("\nisMS: true"))or("")) ..
                      (((isIntel)and("\nisIntel: true"))or("")) ..
                      "\ncanFBO:" .. tostring(canFBO) ..
                      "\ncanRTT:" .. tostring(canRTT) ..
                      "\ncanCTT:" .. tostring(canCTT) ..
                      "\ncanShader:" .. tostring(canShader) .. "\n"
      log = sysinfo..log
    end
    return log
  else
    if (errorlog~="") then
      local sysinfo = "Vendor:" .. glVendor ..
                      "\nRenderer:" .. glRenderer ..
                      "\nNVseries:" .. NVseries ..
                      "\nisATI:" .. tostring(isATI) ..
                      "\nisMS:" .. tostring(isMS) ..
                      "\nisIntel:" .. tostring(isIntel) ..
                      "\ncanFBO:" .. tostring(canFBO) ..
                      "\ncanRTT:" .. tostring(canRTT) ..
                      "\ncanCTT:" .. tostring(canCTT) ..
                      "\ncanShader:" .. tostring(canShader) .. "\n"
      return sysinfo..errorLog
    else
      return errorLog
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local anyFXVisible = false
local anyDistortionsVisible = false

local function Draw(extension,layer)
  local FxLayer = RenderSequence[layer];
  if (not FxLayer) then return end

  local BeginDrawPass = "BeginDraw"..extension
  local DrawPass      = "Draw"..extension
  local EndDrawPass   = "EndDraw"..extension

  for partClass,Units in pairs(FxLayer) do
    local beginDraw = partClass[BeginDrawPass]
    if (beginDraw) then

      beginDraw()

      if (not next(Units)) then
        FxLayer[partClass]=nil
      else
        for unitID,UnitEffects in pairs(Units) do 
          if (not UnitEffects[1]) then 
            Units[unitID]=nil
          else

            if (unitID>-1) then

              ------------------------------------------------------------------------------------
              -- render in unit/piece space ------------------------------------------------------
              ------------------------------------------------------------------------------------
              glPushMatrix()
              glUnitMultMatrix(unitID)

              --// render effects
              for i=1,#UnitEffects do
                local fx = UnitEffects[i]
                if (fx.visible) then
                  if (fx.piecenum) then
                    --// enter piece space
                    glPushMatrix()
                      glUnitPieceMultMatrix(unitID,fx.piecenum)
                      glScale(1,1,-1)
                      fx[DrawPass](fx)
                    glPopMatrix()
                    --// leave piece space
                  else
                    fx[DrawPass](fx)
                  end
                end
              end

              --// leave unit space
              glPopMatrix()

            else

              ------------------------------------------------------------------------------------
              -- render in world space -----------------------------------------------------------
              ------------------------------------------------------------------------------------
              for i=1,#UnitEffects do
                local fx = UnitEffects[i]
                if (fx.visible) then
                  fx[DrawPass](fx)
                end
              end

            end
          end  --if
        end  --for
      end

      partClass[EndDrawPass]()

    end
  end
end

local function DrawDistortionLayers()
  glBlending(GL_ONE,GL_ONE)

  for i=-50,50 do
    Draw("Distortion",i)
  end

  glBlending(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA)
end

local function DrawParticlesOpaque()
  if ( not anyFXVisible ) then return end

  vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
  if (vsx~=oldVsx)or(vsy~=oldVsy) then
    for _,partClass in pairs(fxClasses) do
      if partClass.ViewResize then partClass.ViewResize(vsx, vsy) end
    end
    oldVsx, oldVsy = vsx, vsy
  end

  glDepthTest(true)
  glDepthMask(true)
  for i=-50,50 do
    Draw("Opaque",i)
  end
  glDepthMask(false)
  glDepthTest(false)
end

local function DrawParticles()
  if ( not anyFXVisible ) then return end

  glDepthTest(true)

  --// Draw() (layers: -50 upto 0)
  glAlphaTest(GL_GREATER, 0)
  for i=-50,0 do
    Draw("",i)
  end
  glAlphaTest(false)

  --// DrawDistortion()
  if (anyDistortionsVisible)and(DistortionClass) then
    DistortionClass.BeginDraw()
    gl.ActiveFBO(DistortionClass.fbo,DrawDistortionLayers)
    DistortionClass.EndDraw()
  end

  --// Draw() (layers: 1 upto 50)
  glAlphaTest(GL_GREATER, 0)
  for i=1,50 do
    Draw("",i)
  end

  glAlphaTest(false)
  glDepthTest(false)
end


local function DrawParticlesWater()
  if ( not anyFXVisible ) then return end

  glDepthTest(true)

  --// DrawOpaque()
  glDepthMask(true)
  for i=-50,50 do
    Draw("Opaque",i)
  end
  glDepthMask(false)

  --// Draw() (layers: -50 upto 50)
  glAlphaTest(GL_GREATER, 0)
  for i=-50,50 do
    Draw("",i)
  end
  glAlphaTest(false)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local DrawWorldPreUnitVisibleFx
local DrawWorldVisibleFx
local DrawWorldReflectionVisibleFx
local DrawWorldRefractionVisibleFx
local DrawWorldShadowVisibleFx
local DrawScreenEffectsVisibleFx
local DrawInMiniMapVisibleFx

local function IsPosInLos(x,y,z)
  local inLos  = Spring.IsPosInLos(x,y,z, LocalAllyTeamID)
  --local _,inLos  = Spring.GetPositionLosState(x,y,z, LocalAllyTeamID)
  return (inLos)
end

local function CreateVisibleFxList()
  local removeFX = {}
  local removeCnt = 1

  for layerID,layer in pairs(RenderSequence) do
    for partClass,Units in pairs(layer) do
      for unitID,UnitEffects in pairs(Units) do
        if (unitID>-1) then
          local x,y,z      = spGetUnitViewPosition(unitID)

          local unitActive = -1
          local underConstruction = nil
          
          local unitRadius = 0
          local maxVisibleRadius = -1
          local minNotVisibleRadius = 1e9
          
          --// check effects
          for i=1,#UnitEffects do
            local fx = UnitEffects[i]

            if (fx.onActive and (unitActive == -1)) then
              unitActive = spGetUnitIsActive(unitID)
            end
            
            if (fx.under_construction == 1) then
              underConstruction = spGetUnitRulesParam(unitID, "under_construction")
            end

            if ((not fx.onActive)or(unitActive)) and (underConstruction ~= 1) then
              if (fx.Visible) then
                fx.visible = fx:Visible()
              elseif (z) then
                unitRadius = unitRadius or (spGetUnitRadius(unitID) + 40)

                local r = fx.radius or 0
                if (r > maxVisibleRadius)and(r < minNotVisibleRadius) then
                  if spIsSphereInView(x,y,z,unitRadius + r) then
                    maxVisibleRadius = r
                  else
                    minNotVisibleRadius = r
                  end
                end

                fx.visible = (r <= maxVisibleRadius)
              end

              if (fx.visible) then
                if (not anyFXVisible) then anyFXVisible = true end
                anyDistortionsVisible = anyDistortionsVisible or partClass.pi.distortion
              end
            else
              fx.visible = false
            end
          end

        else

          for i=1,#UnitEffects do
            local fx = UnitEffects[i]
            fx.visible = false
              
            if (fx.Visible) then
              if (fx:Visible()) then
                fx.visible = true
                if (not anyFXVisible) then anyFXVisible = true end
                anyDistortionsVisible = anyDistortionsVisible or partClass.pi.distortion
              end
            elseif (fx.pos) then
              local pos = fx.pos
              if (IsPosInLos(pos[1],pos[2],pos[3]))and
                 (spIsSphereInView(pos[1],pos[2],pos[3],(fx.radius or 200)+100))
              then
                fx.visible = true
                if (not anyFXVisible) then anyFXVisible = true end
                anyDistortionsVisible = anyDistortionsVisible or partClass.pi.distortion
              end
            end

            if (not fx.visible)and(fx.Valid and (not fx:Valid())) then
              removeFX[removeCnt] = fx.id
              removeCnt = removeCnt + 1
            end
          end

        end --if
      end --for
    end --for
  end --for
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CleanInvalidUnitFX()
  local removeFX = {}
  local removeCnt = 1

  for layerID,layer in pairs(RenderSequence) do
    for partClass,Units in pairs(layer) do
      for unitID,UnitEffects in pairs(Units) do
        if (not UnitEffects[1]) then
          Units[unitID] = nil
        else
          if (unitID>-1) then
            if (not spValidUnitID(unitID)) then --// UnitID isn't valid anymore, remove all correspondend effects
              for i=1,#UnitEffects do
                local fx = UnitEffects[i]
                removeFX[removeCnt] = fx.id
                removeCnt = removeCnt + 1
              end
              Units[unitID]=nil
            end
          end
        end
      end
    end
  end

  for i=1,removeCnt-1 do
    RemoveParticles(removeFX[i])
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local this = widget or gadget

local lastGameFrame = 0

local function GameFrame(_,n)
  thisGameFrame = n

  if ((not next(particles)) and (not effectsInDelay[1])) then return end

  --// update team/player status
  local spec, specFullView = spGetSpectatingState()
  if (specFullView) then
    LocalAllyTeamID = scGetReadAllyTeam()
  else
    LocalAllyTeamID = spGetLocalAllyTeamID()
  end

  --// create delayed FXs
  if (effectsInDelay[1]) then
    local remaingFXs,cnt={},1
    for i=1,#effectsInDelay do
      local fx = effectsInDelay[i]
      if (fx.frame>thisGameFrame) then
        remaingFXs[cnt]=fx
        cnt=cnt+1
      else
        AddParticles(fx.class,fx.options, fx.id)
        if (fx.frame-thisGameFrame>0) then
          particles[fx.id]:Update(fx.frame-thisGameFrame)
        end
      end
    end
    effectsInDelay = remaingFXs
  end

  --// cleanup FX from dead/invalid units
  CleanInvalidUnitFX()

  --// update FXs
  framesToUpdate = thisGameFrame - lastGameFrame
  for _,partFx in pairs(particles) do
    if (n>=partFx.dieGameFrame) then
      --// lifetime ended
      if (partFx.repeatEffect) then
        if (type(partFx.repeatEffect)=="number") then
          partFx.repeatEffect = partFx.repeatEffect - 1
          if (partFx.repeatEffect==1) then partFx.repeatEffect = nil end
        end
        if (partFx.ReInitialize) then
          partFx:ReInitialize()
        else
          partFx.dieGameFrame = partFx.dieGameFrame + partFx.life
        end
      else
        RemoveParticles(partFx.id)
      end
    else
      --// update particles
      if (partFx.Update) then
        partFx:Update(framesToUpdate)
      end
    end
  end
end

local function DestroyFX()
  for i=1,#fxToDestroy do
    fxToDestroy[i]:Destroy()
  end
  fxToDestroy = {}
end

local function Update(_,dt)
  --// update frameoffset
  frameOffset = spGetFrameTimeOffset()

  --// Game Frame Update
  local x = spGetGameFrame()

  if ((x-lastGameFrame)>=1) then
    GameFrame(nil,x)
    lastGameFrame = x
  end

  --// check which fxs are visible
  anyFXVisible = false
  anyDistortionsVisible = false
  if (next(particles)) then
    CreateVisibleFxList()
  end

  DestroyFX()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function Initialize()
  LupsConfig = LoadConfig("./lups.cfg")

  --// overwrite detected hardware with lups.cfg
  local forcevendor   = GetLupsSetting("vendor",nil)
  local forcerenderer = GetLupsSetting("renderer",nil)
  if (forcevendor or forcerenderer) then
    glVendor,glRenderer = forcevendor or glVendor,forcerenderer or glRenderer
    DetectCard(glVendor,glRenderer)
  end
  --canFBO    = GetLupsSetting("fbo",canFBO)
  --canRTT    = GetLupsSetting("rtt",canRTT)
  --canCTT    = GetLupsSetting("ctt",canCTT)
  --canShader = GetLupsSetting("shader",canShader)

  --// set verbose level
  local showWarnings = LupsConfig.showwarnings
  if showWarnings then
    local t = type(showWarnings)
    if (t=="number") then
      printErrorsAbove = showWarnings
    elseif (t=="boolean") then
      printErrorsAbove = PRIO_LESS
    end
  end


  --// is distortion is supported?
  DistortionClass = fxClasses["postdistortion"]
  if DistortionClass then
    fxClasses["postdistortion"]=nil --// remove it from default classes
    local di = DistortionClass.pi
    if (di)and

       (canShader or (not di.shader))and
       (canFBO or (not di.fbo))and
       (canRTT or (not di.rtt))and
       (canCTT or (not di.ctt))and

       ( (isNvidia and (NVseries >= (di.nvseries or 0)))  or true)and
       ( (isATI and   (ATIseries >= (di.atiseries or 0))) or true)and

       ((not isIntel) or (di.intel~=0))and
       ((not isMS)  or (di.ms~=0))
    then
      local fine = true
      if (DistortionClass.Initialize) then fine = DistortionClass.Initialize() end
      if (fine~=nil)and(fine==false) then
        print(PRIO_LESS,'LUPS: disabled Distortions');
        DistortionClass=nil
      end
    else
      print(PRIO_LESS,'LUPS: disabled Distortions');
      DistortionClass=nil
    end
  end
  canDistortions = (DistortionClass~=nil)


  --// get list of user disabled fx classes
  local disableFX = {}
  for i,v in pairs(LupsConfig.disablefx or {}) do
    disableFX[i:lower()]=v;
  end

  local linkBackupFXClasses = {}

  --// initialize particle classes
  for fxName,fxClass in pairs(fxClasses) do
    local fi = fxClass.pi --// .fi = fxClass.GetInfo()
    if (fi)and
       (not disableFX[fxName])and

       (canShader or (not fi.shader))and
       (canFBO or (not fi.fbo))and
       (canRTT or (not fi.rtt))and
       (canCTT or (not fi.ctt))and
       (canDistortions or (not fi.distortion))and

       ( (isNvidia and (NVseries >= (fi.nvseries or 0)))  or true)and
       ( (isATI and   (ATIseries >= (fi.atiseries or 0))) or true)and
       ((not isIntel) or (fi.intel~=0))and
       ((not isMS)  or (fi.ms~=0))
    then
      local fine = true
      if (fxClass.Initialize) then fine = fxClass.Initialize() end
      if (fine~=nil)and(fine==false) then
        print(PRIO_LESS,'LUPS: "' .. fi.name .. '" FXClass removed (class requested it during initialization)');
        fxClasses[fxName]=nil
        if (fi.backup and fi.backup~="") then
          linkBackupFXClasses[fxName] = fi.backup:lower()
        end
        if (fxClass.Finalize) then fxClass.Finalize() end
      end
    else --// unload particle class (not supported by this computer)
      print(PRIO_LESS,'LUPS: "' .. fi.name .. '" FXClass removed (hardware doesn\'t support it)');
      fxClasses[fxName]=nil
      if (fi.backup and fi.backup~="") then
        linkBackupFXClasses[fxName] = fi.backup:lower()
      end
    end
  end

  --// link backup FXClasses
  for className,backupName in pairs(linkBackupFXClasses) do
    fxClasses[className]=fxClasses[backupName]
  end

  --// link Distortion Class
  fxClasses["postdistortion"]=DistortionClass

  --// update screen geometric
  --ViewResize(_,handler:GetViewSizes())

  --// make global
  GG.Lups = {}
  GG.Lups.GetStats          = GetStats
  GG.Lups.GetErrorLog       = GetErrorLog
  GG.Lups.AddParticles      = AddParticles
  GG.Lups.RemoveParticles   = RemoveParticles
  GG.Lups.AddParticlesArray = AddParticlesArray
  GG.Lups.HasParticleClass  = HasParticleClass

  for fncname,fnc in pairs(GG.Lups) do
    handler:RegisterGlobal('Lups_'..fncname,fnc)
  end

  GG.Lups.Config = LupsConfig

  nilDispList = gl.CreateList(function() end)
end

local function Shutdown()
  for fncname,fnc in pairs(GG.Lups) do
    handler:DeregisterGlobal('Lups_'..fncname)
  end
  GG.Lups = nil

  for _,fxClass in pairs(fxClasses) do
    if (fxClass.Finalize) then
      fxClass.Finalize()
    end
  end

  gl.DeleteList(nilDispList)

  DestroyFX()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


this.GetInfo    = GetInfo
this.Initialize = Initialize
this.Shutdown   = Shutdown
this.DrawWorldPreUnit    = DrawParticlesOpaque
this.DrawWorld           = DrawParticles
this.DrawWorldReflection = DrawParticlesWater
this.DrawWorldRefraction = DrawParticlesWater
this.ViewResize = ViewResize
this.Update     = Update
if gadget then
  this.DrawUnit = DrawUnit
  --this.GameFrame  = GameFrame; // doesn't work for unsynced parts >yet<
end