-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  author:  jK
--
--  Copyright (C) 2008,2009,2010.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "CustomUnitShaders",
    desc      = "allows to override the engine unit shader",
    author    = "jK",
    date      = "2008,2009,2010",
    license   = "GNU GPL, v2 or later",
    layer     = 1,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Synced
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


if (gadgetHandler:IsSyncedCode()) then

  function gadget:UnitFinished(unitID,unitDefID,teamID)
    SendToUnsynced("unitshaders_finished", unitID, unitDefID,teamID)
  end

  function gadget:UnitDestroyed(unitID,unitDefID,teamID)
    SendToUnsynced("unitshaders_destroyed", unitID, unitDefID,teamID)
  end

  function gadget:UnitReverseBuild(unitID,unitDefID,teamID)
    SendToUnsynced("unitshaders_reverse", unitID, unitDefID,teamID)
  end

  function gadget:UnitGiven(unitID,unitDefID,teamID)
    SendToUnsynced("unitshaders_given", unitID, unitDefID,teamID)
  end

  function gadget:UnitCloaked(unitID,unitDefID,teamID)
    SendToUnsynced("unitshaders_cloak", unitID, unitDefID,teamID)
  end

  function gadget:UnitDecloaked(unitID,unitDefID,teamID)
    SendToUnsynced("unitshaders_decloak", unitID, unitDefID,teamID)
  end

  --// block first try, so we have enough time to disable the lua UnitRendering
  --// else the model would be invisible for 1 gameframe
  local blockFirst = {}
  function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part)
    if (part < 0) then
      local inbuild = not select(3,Spring.GetUnitIsStunned(unitID))
      if (not inbuild) then
        gadget:UnitReverseBuild(unitID,unitDefID,Spring.GetUnitTeam(unitID))
        if (not blockFirst[unitID]) then
          blockFirst[unitID] = true
          return false
        end
      end
    else
      blockFirst[unitID] = nil
    end
    return true
  end

  function gadget:GameFrame()
    for i,uid in ipairs(Spring.GetAllUnits()) do
      if not select(3,Spring.GetUnitIsStunned(uid)) then --// inbuild?
        gadget:UnitFinished(uid,Spring.GetUnitDefID(uid),Spring.GetUnitTeam(uid))
      end
    end
    gadgetHandler:RemoveCallIn('GameFrame')
  end

  return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Unsynced
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

VFS.Include("LuaRules/UnitRendering.lua")

if (not gl.CreateShader) then
  return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local shadows = false
local advShading = false
local normalmapping = false

local drawUnitList = {}
local unitMaterialInfos,bufMaterials = {},{}
local materialDefs = {}
local loadedTextures = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local _plugins = nil
local function InsertPlugin(str)
  --str = str:upper()
  return (_plugins and _plugins[str]) or ""
end


local function CompileShader(shader, definitions, plugins)
  shader.vertexOrig   = shader.vertex
  shader.fragmentOrig = shader.fragment
  shader.geometryOrig = shader.geometry

  --// insert small pieces of code named `plugins`
  --// this way we can use a basic shader and add some simple vertex animations etc.
  do
    if (plugins) then
      _plugins = plugins
    end

    if (shader.vertex)
      then shader.vertex   = shader.vertex:gsub("%%%%([%a_]+)%%%%", InsertPlugin); end
    if (shader.fragment)
      then shader.fragment = shader.fragment:gsub("%%%%([%a_]+)%%%%", InsertPlugin); end
    if (shader.geometry)
      then shader.geometry = shader.geometry:gsub("%%%%([%a_]+)%%%%", InsertPlugin); end

    _plugins = nil
  end

  --// append definitions at top of the shader code
  --// (this way we can modularize a shader and enable/disable features in it)
  if (definitions or shadows) then
    definitions = definitions or {}
    definitions = table.concat(definitions, "\n")
    if (shadows) then
      definitions = definitions .. "\n" .. "#define use_shadows" .. "\n"
    end
    if (shader.vertex)
      then shader.vertex = definitions .. shader.vertex; end
    if (shader.fragment)
      then shader.fragment = definitions .. shader.fragment; end
    if (shader.geometry)
      then shader.geometry = definitions .. shader.geometry; end
  end

  local GLSLshader = gl.CreateShader(shader)
  local errorLog = gl.GetShaderLog()
  if (errorLog and errorLog~= "") then
    Spring.Echo("Custom Unit Shaders:", errorLog)
  end

  shader.vertex   = shader.vertexOrig
  shader.fragment = shader.fragmentOrig
  shader.geometry = shader.geometryOrig

  return GLSLshader
end


local function CompileMaterialShaders()
  for _,mat_src in pairs(materialDefs) do
    if (mat_src.shaderSource) then
      local GLSLshader = CompileShader(mat_src.shaderSource, mat_src.shaderDefinitions, mat_src.shaderPlugins)

      if (GLSLshader) then
        if (mat_src.shader) then
          gl.DeleteShader(mat_src.shader)
        end
        mat_src.shader          = GLSLshader
        mat_src.cameraLoc       = gl.GetUniformLocation(GLSLshader,"camera")
        mat_src.cameraInvLoc    = gl.GetUniformLocation(GLSLshader,"cameraInv")
        mat_src.cameraPosLoc    = gl.GetUniformLocation(GLSLshader,"cameraPos")
        mat_src.shadowMatrixLoc = gl.GetUniformLocation(GLSLshader,"shadowMatrix")
        mat_src.shadowParamsLoc = gl.GetUniformLocation(GLSLshader,"shadowParams")
        mat_src.sunLoc          = gl.GetUniformLocation(GLSLshader,"sunPos")
        mat_src.frameLoc        = gl.GetUniformLocation(GLSLshader,"frameLoc")
        mat_src.speedLoc        = gl.GetUniformLocation(GLSLshader,"speed")
        mat_src.healthLoc        = gl.GetUniformLocation(GLSLshader,"healthLoc")
      end
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function GetUnitMaterial(unitDefID)
  local mat = bufMaterials[unitDefID]
  if (mat) then
    return mat
  end

  local matInfo = unitMaterialInfos[unitDefID]
  local mat = materialDefs[matInfo[1]]

  matInfo.UNITDEFID = unitDefID

  --// find unitdef tex keyword and replace it
  --// (a shader can be just for multiple unitdefs, so we support this keywords)
  local texUnits = {}
  for texid,tex in pairs(mat.texunits or {}) do
    local tex_ = tex
    for varname,value in pairs(matInfo) do
      tex_ = tex_:gsub("%%"..tostring(varname),value)
    end
    texUnits[texid] = {tex=tex_, enable=false}
  end

  --// materials don't load those textures themselves
  if (texUnits[1]) then
    local texdl = gl.CreateList(function()
    for _,tex in pairs(texUnits) do
      local prefix = tex.tex:sub(1,1)
      if   (prefix~="%") 
        and(prefix~="#")
        and(prefix~="!")
        and(prefix~="$")
      then
        gl.Texture(tex.tex)
        loadedTextures[#loadedTextures+1] = tex.tex
      end
    end
    end)
    gl.DeleteList(texdl)
  end

  local luaMat = Spring.UnitRendering.GetMaterial("opaque",{
                   shader          = mat.shader,
                   cameraposloc    = mat.cameraPosLoc,
                   cameraloc       = mat.cameraLoc,
                   camerainvloc    = mat.cameraInvLoc,
                   shadowloc       = mat.shadowMatrixLoc,
                   shadowparamsloc = mat.shadowParamsLoc,
                   usecamera       = mat.usecamera,
                   culling         = mat.culling,
                   texunits        = texUnits,
                   prelist         = mat.predl,
                   postlist        = mat.postdl,
                   --frameLoc        = mat.frameLoc,
                 })

  bufMaterials[unitDefID] = luaMat

  return luaMat
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function ToggleShadows()
  shadows = Spring.HaveShadows()

  CompileMaterialShaders()

  bufMaterials = {}

  local units = Spring.GetAllUnits()
  for _,unitID in pairs(units) do
    local unitDefID = Spring.GetUnitDefID(unitID)
    local teamID    = Spring.GetUnitTeam(unitID)
    UnitDestroyed(nil,unitID)
    Spring.UnitRendering.DeactivateMaterial(unitID,3)
    if not select(3,Spring.GetUnitIsStunned(unitID)) then --// inbuild?
      UnitFinished(nil,unitID,unitDefID,teamID)
    end
  end
end


function ToggleAdvShading()
  advShading = Spring.HaveAdvShading()

  if (not advShading) then
    --// unload all materials
    drawUnitList = {}

    local units = Spring.GetAllUnits()
    for _,unitID in pairs(units) do
      Spring.UnitRendering.DeactivateMaterial(unitID,3)
    end
  elseif (normalmapping) then
    --// reinitializes all shaders
    ToggleShadows()
  end
end


function ToggleNormalmapping(_,_,_, playerID)
  if (playerID ~= Spring.GetMyPlayerID()) then
    return
  end

  normalmapping = not normalmapping
  Spring.SetConfigInt("NormalMapping", (normalmapping and 1) or 0)
  Spring.Echo("Set NormalMapping to " .. tostring((normalmapping and 1) or 0))

  if (not normalmapping) then
    --// unload normalmapped materials
    local units = Spring.GetAllUnits()
    for _,unitID in pairs(units) do
      local unitDefID = Spring.GetUnitDefID(unitID)
      local unitMat = unitMaterialInfos[unitDefID]
      if (unitMat) then
        local mat = materialDefs[unitMat[1]]
        if (not mat.force) then
          gadget:UnitDestroyed(unitID,unitDefID)
        end
      end
    end
  elseif (advShading) then
    --// reinitializes all shaders
    ToggleShadows()
  end
  return true
end


local n = -1
function gadget:Update()
  if (n<Spring.GetDrawFrame()) then
    n = Spring.GetDrawFrame() + Spring.GetFPS()

    if (advShading ~= Spring.HaveAdvShading()) then
      ToggleAdvShading()
    elseif (advShading)and(normalmapping)and(shadows ~= Spring.HaveShadows()) then
      ToggleShadows()
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:UnitFinished(unitID,unitDefID,teamID)
  local unitMat = unitMaterialInfos[unitDefID]
  if (unitMat) then
    local mat = materialDefs[unitMat[1]]
    if (normalmapping or mat.force) then
      Spring.UnitRendering.ActivateMaterial(unitID,3)
      Spring.UnitRendering.SetMaterial(unitID,3,"opaque",GetUnitMaterial(unitDefID))
      for pieceID in ipairs(Spring.GetUnitPieceList(unitID) or {}) do
        Spring.UnitRendering.SetPieceList(unitID,3,pieceID)
      end

      if (mat.DrawUnit) then
        Spring.UnitRendering.SetUnitLuaDraw(unitID,true)
        drawUnitList[unitID] = mat
      end

      if (mat.UnitCreated) then
        mat.UnitCreated(unitID, mat, 3)
      end
    end
  end
end

function gadget:UnitDestroyed(unitID,unitDefID)
  Spring.UnitRendering.DeactivateMaterial(unitID,3)

  local mat = drawUnitList[unitID]
  if (mat) then
    if (mat.UnitDestroyed) then
      mat.UnitDestroyed(unitID, 3)
    end
    drawUnitList[unitID] = nil
  end
end


function gadget:DrawUnit(unitID)
  local mat = drawUnitList[unitID]
  if (mat) then
    --gl.Uniform(mat.frameLoc, math.random()) --nope
    return mat.DrawUnit(unitID, mat)
  end
end

gadget.UnitReverseBuild = gadget.UnitDestroyed
gadget.UnitCloaked   = gadget.UnitDestroyed
gadget.UnitDecloaked = gadget.UnitFinished

function gadget:UnitGiven(...)
  gadget:UnitDestroyed(...)
  gadget:UnitFinished(...)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function tmerge(tout,tin)
  for i,v in pairs(tin) do
    if (not tout[i]) then
      tout[i] = v
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// Workaround: unsynced LuaRules doesn't receive Shutdown events
Shutdown = Script.CreateScream()
Shutdown.func = function()
  --// unload textures, so the user can do a `/luarules reload` to reload the normalmaps
  for i=1,#loadedTextures do
    gl.DeleteTexture(loadedTextures[i])
  end
end


function gadget:Initialize()
  --// check user configs
  shadows = Spring.HaveShadows()
  advShading = Spring.HaveAdvShading()
  normalmapping = (Spring.GetConfigInt("NormalMapping", 1)>0)

  --// load the materials config files
  local unitMaterialDefs = {}
  do
    local GADGET_DIR = "LuaRules/Configs/"
    local MATERIALS_DIR = GADGET_DIR .. "UnitMaterials/"

    local files = VFS.DirList(MATERIALS_DIR)
    table.sort(files)

    for i=1,#files do
      local mats, unitMats = VFS.Include(files[i])
      tmerge(materialDefs, mats)
      tmerge(unitMaterialDefs, unitMats)
    end
  end

  --// process the materials (compile shaders, load textures, ...)
  do
    for _,mat_src in pairs(materialDefs) do
      if (mat_src.shader)and
         (mat_src.shader ~= "3do")and(mat_src.shader ~= "s3o")
      then
        mat_src.shaderSource = mat_src.shader
        mat_src.shader = nil
      end
    end

    CompileMaterialShaders()

    for unitName,materialInfo in pairs(unitMaterialDefs) do
      if (type(materialInfo) ~= "table") then
        materialInfo = {materialInfo}
      end
      unitMaterialInfos[(UnitDefNames[unitName] or {id=-1}).id] = materialInfo
    end
  end

  --// insert synced actions
  gadgetHandler:AddSyncAction("unitshaders_finished", UnitFinished)
  gadgetHandler:AddSyncAction("unitshaders_destroyed", UnitDestroyed)
  gadgetHandler:AddSyncAction("unitshaders_reverse", UnitReverseBuild)
  gadgetHandler:AddSyncAction("unitshaders_given", UnitGiven)
  gadgetHandler:AddSyncAction("unitshaders_cloak", UnitCloaked)
  gadgetHandler:AddSyncAction("unitshaders_decloak", UnitDecloaked)

  gadgetHandler:AddChatAction("normalmapping", ToggleNormalmapping)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
