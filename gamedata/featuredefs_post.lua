--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    featuredefs_post.lua
--  brief:   featureDef post processing
--  author:  Dave Rodgers
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Per-unitDef featureDefs
--

local function isbool(x)   return (type(x) == 'boolean') end
local function istable(x)  return (type(x) == 'table')   end
local function isnumber(x) return (type(x) == 'number')  end
local function isstring(x) return (type(x) == 'string')  end


--------------------------------------------------------------------------------

local function ProcessUnitDef(udName, ud)

  local fds = ud.featuredefs
  if (not istable(fds)) then
    return
  end

  -- add this unitDef's featureDefs
  for fdName, fd in pairs(fds) do
    if (isstring(fdName) and istable(fd)) then
      local fullName = udName .. '_' .. fdName
      FeatureDefs[fullName] = fd
      fd.customparams = fd.customparams or {}
      fd.customparams.fromunit = 1
    end
  end

  -- FeatureDead name changes
  for fdName, fd in pairs(fds) do
    if (isstring(fdName) and istable(fd)) then
      if (isstring(fd.featuredead)) then
        local fullName = udName .. '_' .. fd.featuredead:lower()
        if (FeatureDefs[fullName]) then
          fd.featuredead = fullName
        end
      end
    end
  end

  -- convert the unit corpse name
  if (isstring(ud.corpse)) then
    local fullName = udName .. '_' .. ud.corpse:lower()
    local fd = FeatureDefs[fullName]
    if (fd) then
      ud.corpse = fullName
    end
  end

end


--------------------------------------------------------------------------------

-- Process the unitDefs
local UnitDefs = DEFS.unitDefs

for udName, ud in pairs(UnitDefs) do
  if (isstring(udName) and istable(ud)) then
    ProcessUnitDef(udName, ud)
  end
end


--------------------------------------------------------------------------------

--------------------------------------------------------------------------------



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
