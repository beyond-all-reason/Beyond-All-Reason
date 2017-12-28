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

local function MergeShieldColor(col, frac)
	return {
		frac*col[1][1] + (1 - frac)*col[2][1],
		frac*col[1][2] + (1 - frac)*col[2][2],
		frac*col[1][3] + (1 - frac)*col[2][3],
		frac*col[1][4] + (1 - frac)*col[2][4],
	}
end

local hitOpacityMult = {1.2, 1.5, 1.5}
local HIT_DURATION = 2
function GetShieldColor(unitID, self)
	local _, charge = Spring.GetUnitShieldState(unitID)
	if charge ~= nil then
		local frac = math.max(0, math.min(1, charge/(self.shieldCapacity or 10000)))
		
		local col1 = MergeShieldColor(self.colormap1, frac)
		local col2 = self.colormap2 and MergeShieldColor(self.colormap2, frac)
		
		if self.hitResposeMult ~= 0 then
			local hitTime = Spring.GetUnitRulesParam(unitID, "shieldHitFrame")
			local frame = Spring.GetGameFrame()
			if hitTime and (hitTime + HIT_DURATION > frame) then
				col1[4] = col1[4]*hitOpacityMult[frame - hitTime + 1]*(self.hitResposeMult or 1)
				if col2 then
					col2[4] = col2[4]*hitOpacityMult[frame - hitTime + 1]*(self.hitResposeMult or 1)
				end
			end
		end
		
		return col1, col2
	end
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