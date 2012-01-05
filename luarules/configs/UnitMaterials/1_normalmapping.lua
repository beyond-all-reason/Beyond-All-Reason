-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local GetGameFrame=Spring.GetGameFrame
local GetUnitHealth=Spring.GetUnitHealth
local modulo=math.fmod
local glUniform=gl.Uniform
local sine =math.sin
local maximum=math.max

local GADGET_DIR = "LuaRules/Configs/"
local function DrawUnit(unitID, material)
  glUniform(material.frameLoc, 2* maximum(0,sine(modulo(unitID,10)+GetGameFrame()/(modulo(unitID,7)+6))))
  health,maxhealth=GetUnitHealth(unitID)
  glUniform(material.healthLoc, 2*maximum(0, (-2*health)/(maxhealth)+1) )--inverse of health, 0 if health is 100%-50%, goes to 1 by 0 health


  --// engine should still draw it (we just set the uniforms for the shader)
  return false
end
local materials = {
   normalMappedS3o = {
       shaderDefinitions = {
	"#define use_perspective_correct_shadows",
         "#define use_normalmapping",
         --"#define flip_normalmap",
       },
       shader    = include(GADGET_DIR .. "UnitMaterials/Shaders/default.lua"),
       usecamera = false,
       culling   = GL.BACK,
       texunits  = {
         [0] = '%%UNITDEFID:0',
         [1] = '%%UNITDEFID:1',
         [2] = '$shadow',
         [3] = '$specular',
         [4] = '$reflection',
         [5] = '%NORMALTEX',
       },
	   DrawUnit = DrawUnit,
   },
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Automated normalmap detection

local unitMaterials = {}



local function FindNormalmap(tex1, tex2)
  local normaltex

  --// check if there is a corresponding _normals.dds file
  if (VFS.FileExists(tex1)) then
    local basefilename = tex1:gsub("%....","")
    --[[if (tonumber(basefilename:sub(-1,-1))) then
      basefilename = basefilename:sub(1,-2)
    end]]-- -- This code removes trailing numbers, but many S44 units end in a number, e.g. SU-76
    if (basefilename:sub(-1,-1) == "_") then
       basefilename = basefilename:sub(1,-2)
    end
    normaltex = basefilename .. "_normals.dds"
    if (not VFS.FileExists(normaltex)) then
      normaltex = nil
    end
  end --if FileExists

  --[[if (not normaltex) and tex2 and (VFS.FileExists(tex2)) then
    local basefilename = tex2:gsub("%....","")
    if (tonumber(basefilename:sub(-1,-1))) then
      basefilename = basefilename:sub(1,-2)
    end
    if (basefilename:sub(-1,-1) == "_") then
      basefilename = basefilename:sub(1,-2)
    end
    normaltex = basefilename .. "_normals.dds"
    if (not VFS.FileExists(normaltex)) then
      normaltex = nil
    end
  end --if FileExists ]] -- disable tex2 detection for S44

  return normaltex
end



for i=1,#UnitDefs do
  local udef = UnitDefs[i]

  if (udef.customParams.normaltex and VFS.FileExists(udef.customParams.normaltex)) then
    unitMaterials[udef.name] = {"normalMappedS3o", NORMALTEX = udef.customParams.normaltex}

  elseif (udef.model.type == "s3o") then
    local modelpath = udef.model.path
    if (modelpath) then
      --// udef.model.textures is empty at gamestart, so read the texture filenames from the s3o directly

      local rawstr = VFS.LoadFile(modelpath)
      local header = rawstr:sub(1,60)
      local texPtrs = VFS.UnpackU32(header, 45, 2)
      local tex1,tex2
      if (texPtrs[2] > 0)
        then tex2 = "unittextures/" .. rawstr:sub(texPtrs[2]+1, rawstr:len()-1)
        else texPtrs[2] = rawstr:len() end
      if (texPtrs[1] > 0)
        then tex1 = "unittextures/" .. rawstr:sub(texPtrs[1]+1, texPtrs[2]-1) end

      -- output units without tex2
      --[[if not tex2 then
        Spring.Echo("CustomUnitShaders: " .. udef.name .. " no tex2")
      end]]

      local normaltex = FindNormalmap(tex1,tex2)
      if (normaltex and not unitMaterials[udef.name]) then
        unitMaterials[udef.name] = {"normalMappedS3o", NORMALTEX = normaltex}
      end
    end --if model

  elseif (udef.model.type == "obj") then
    local modelinfopath = udef.model.path
    if (modelinfopath) then
      modelinfopath = modelinfopath .. ".lua"

      if (VFS.FileExists(modelinfopath)) then
        local infoTbl = Include(modelinfopath)
        if (infoTbl) then
          local tex1 = "unittextures/" .. (infoTbl.tex1 or "")
          local tex2 = "unittextures/" .. (infoTbl.tex2 or "")

          -- output units without tex2
          --[[if not tex2 then
            Spring.Echo("CustomUnitShaders: " .. udef.name .. " no tex2")
          end]]

          local normaltex = FindNormalmap(tex1,tex2)
          if (normaltex and not unitMaterials[udef.name]) then
            unitMaterials[udef.name] = {"normalMappedS3o", NORMALTEX = normaltex}
          end
        end
      end
    end

  end --elseif
end --for

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
