--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unitdefs.lua
--  brief:   unitdef parser
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local unitDefs = {}

local shared = {} -- shared amongst the lua unitdef enviroments

local preProcFile  = 'gamedata/unitdefs_pre.lua'
local postProcFile = 'gamedata/unitdefs_post.lua'

local FBI = FBIparser or VFS.Include('gamedata/parse_fbi.lua')
local TDF = TDFparser or VFS.Include('gamedata/parse_tdf.lua')
local DownloadBuilds = VFS.Include('gamedata/download_builds.lua')

local system = VFS.Include('gamedata/system.lua')
VFS.Include('gamedata/VFSUtils.lua')


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Run a pre-processing script if one exists
--

if (VFS.FileExists(preProcFile)) then
  Shared   = shared    -- make it global
  UnitDefs = unitDefs  -- make it global
  VFS.Include(preProcFile)
  UnitDefs = nil
  Shared   = nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Load the FBI unitdef files
--

local fbiFiles = RecursiveFileSearch('units/', '*.fbi') 

function name_from_filename(filename)
  local xname = nil
  _,e = string.find(filename, "units/");
  s2,_ = string.find(filename, ".fbi")
  xname = string.sub(filename, e+1, s2-1);
  return xname;
end

function print_tbl(name, ud)
  if (type(ud) ~= "table") then
    return nil;
  end
  Spring.Echo("local unitDef = {");
  local print_sub = nil;
  print_sub = function(ind, sd)
    for k, v in pairs(sd) do
      if (type(v) ~= "table") then
	if (type(v) ~= "number" and type(v) ~= "string") then
	  Spring.Echo("ERROR: Wrong type(v);");
	  local x = "FAIL"; return x[1234];
	end
	local kk = nil;
	local vv = nil;
	if (tonumber(k) ~= nil) then
	  kk = "[" .. tostring(k) .. "]";
	else
	  kk = tostring(k);
	end
	if (tonumber(v) ~= nil) then
	  vv = tonumber(v);
	else
	  vv = "[[" .. tostring(v) .. "]]";
	end
	Spring.Echo(ind .. kk .. " = " .. vv .. ",");
      else
        local kk = nil;
	if (tonumber(k) ~= nil) then
	  kk = "[" .. tostring(k) .. "]";
	else
	  kk = "[\"" .. tostring(k) .. "\"]";
	end
        Spring.Echo(ind .. kk .. " = {");
        print_sub(ind .. "  ", v);
	Spring.Echo(ind .. "},");
      end
    end
  end
  print_sub("  ", ud);
  Spring.Echo("}");
  Spring.Echo("");
  Spring.Echo("return lowerkeys({ [\"" .. tostring(name) .. "\"] = unitDef })");
end

for _, filename in ipairs(fbiFiles) do
  local ud, err = FBI.Parse(filename)
  local name = name_from_filename(filename);
  Spring.Echo("|||||| " .. tostring(name));
  print_tbl(name, ud);
  if (ud == nil) then
    Spring.Echo('Error parsing ' .. filename .. ': ' .. err)
  elseif (ud.unitname == nil) then
    Spring.Echo('Missing unitName in ' .. filename)
  else
    ud.filename = filename
    ud.unitname = string.lower(ud.unitname)
    unitDefs[ud.unitname] = ud
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Load the raw LUA format unitdef files
--  (these will override the FBI/SWU versions)
--


local luaFiles = RecursiveFileSearch('units/', '*.lua')

for _, filename in ipairs(luaFiles) do
  local udEnv = {}
  udEnv._G = udEnv
  udEnv.Shared = shared
  udEnv.GetFilename = function() return filename end
  setmetatable(udEnv, { __index = system })
  local success, uds = pcall(VFS.Include, filename, udEnv)
  if (not success) then
    Spring.Echo('Error parsing ' .. filename .. ': ' .. uds)
  elseif (type(uds) ~= 'table') then
    Spring.Echo('Bad return table from: ' .. filename)
  else
    for udName, ud in pairs(uds) do
      if ((type(udName) == 'string') and (type(ud) == 'table')) then
        ud.filename = filename
        unitDefs[udName] = ud
      else
        Spring.Echo('Bad return table entry from: ' .. filename)
      end
    end
  end  
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Insert the download build entries
--

DownloadBuilds.Execute(unitDefs)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Run a post-processing script if one exists
--

if (VFS.FileExists(postProcFile)) then
  Shared   = shared    -- make it global
  UnitDefs = unitDefs  -- make it global
  VFS.Include(postProcFile)
  UnitDefs = nil
  Shared   = nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Basic checks to kill unitDefs that will crash ".give all"
--

for name, def in pairs(unitDefs) do
  local cob = 'scripts/'   .. name .. '.cob'

  local obj = def.objectName or def.objectname
  if (obj == nil) then
    unitDefs[name] = nil
    Spring.Echo('WARNING: removed ' .. name ..
                ' unitDef, missing objectname param')
    for k,v in pairs(def) do print('',k,v) end
  else
    local objfile = 'objects3d/' .. obj
    if ((not VFS.FileExists(objfile))           and
        (not VFS.FileExists(objfile .. '.3do')) and
        (not VFS.FileExists(objfile .. '.s3o'))) then
      unitDefs[name] = nil
      Spring.Echo('WARNING: removed ' .. name
                  .. ' unitDef, missing model file  (' .. obj .. ')')
    end
  end
end


for name, def in pairs(unitDefs) do
  local badOptions = {}
  local buildOptions = def.buildOptions or def.buildoptions
  if (buildOptions) then
    for i, option in ipairs(buildOptions) do
      if (unitDefs[option] == nil) then
        table.insert(badOptions, i)
        Spring.Echo('WARNING: removed the "' .. option ..'" entry'
                    .. ' from the "' .. name .. '" build menu')
      end
    end
    if (#badOptions > 0) then
      local removed = 0
      for _, badIndex in ipairs(badOptions) do
        table.remove(buildOptions, badIndex - removed)
        removed = removed + 1
      end
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return unitDefs

--------------------------------------------------------------------------------
-------------------------------------------------------------------------------- 
