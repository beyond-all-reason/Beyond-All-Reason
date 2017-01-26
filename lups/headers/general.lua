-- $Id: general.lua 3171 2008-11-06 09:06:29Z det $
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    general.h.lua
--  brief:   collection of some usefull functions used in LUPS
--  authors: jK
--  last updated: 30 Oct. 2007
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

local floor = math.floor
function GetColor(colormap,life)
  local ncolors = #colormap
  if (life>=1)or(ncolors==1) then
    local col = colormap[ncolors]
    return col[1],col[2],col[3],col[4]
  end
  local posn  = 1 + (ncolors-1) * life
  local iposn = floor(posn)
  local aa = posn - iposn
  local ia = 1-aa

  local col1,col2 = colormap[iposn],colormap[iposn+1]

  return col1[1]*ia + col2[1]*aa, col1[2]*ia + col2[2]*aa,
         col1[3]*ia + col2[3]*aa, col1[4]*ia + col2[4]*aa
end

local type  = type
local pairs = pairs
function CopyTable(outtable,intable)
  for i,v in pairs(intable) do 
    if (type(v)=='table') then
      if (type(outtable[i])~='table') then outtable[i] = {} end
      CopyTable(outtable[i],v)
    else
      outtable[i] = v
    end
  end
end
local CopyTable = CopyTable

function MergeTable(table1,table2)
  local ret = {}
  CopyTable(ret,table2)
  CopyTable(ret,table1)
  return ret
end

function CreateSubTables(startTable,SubIndexes)
  for i=1,#SubIndexes do
    local v = SubIndexes[i]
    if (startTable[v] == nil) then startTable[v] = {} end
    startTable = startTable[v]
  end
  return startTable
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------