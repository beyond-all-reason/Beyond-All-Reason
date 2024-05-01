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


local function MergeShieldColorNoT(col, frac)
	return 
		frac*col[1][1] + (1 - frac)*col[2][1],
		frac*col[1][2] + (1 - frac)*col[2][2],
		frac*col[1][3] + (1 - frac)*col[2][3],
		frac*col[1][4] + (1 - frac)*col[2][4]
end


local hitOpacityMult = {1.2, 1.5, 1.5}
local HIT_DURATION = 2
function GetShieldColor(unitID, self)
	local _, charge = Spring.GetUnitShieldState(unitID)
	if charge ~= nil then
		local frac = charge / (self.shieldCapacity or 10000)
        if frac > 1 then frac = 1 elseif frac < 0 then frac = 0 end

		local col1r, col1g, col1b, col1a  = MergeShieldColorNoT(self.colormap1, frac)
		local col2r, col2g, col2b, col2a = 0,0,0,0
		if self.colormap2 then 
			col2r, col2g, col2b, col2a = MergeShieldColorNoT(self.colormap2, frac)
		end
		--local col2 = self.colormap2 and MergeShieldColor(self.colormap2, frac)
		
		if self.hitResposeMult ~= 0 then
			local hitTime = Spring.GetUnitRulesParam(unitID, "shieldHitFrame")
			local frame = Spring.GetGameFrame()
			if hitTime and (hitTime + HIT_DURATION > frame) then
				col1a = col1a*hitOpacityMult[frame - hitTime + 1]*(self.hitResposeMult or 1)
				if col2a > 0 then
					col2a = col2a*hitOpacityMult[frame - hitTime + 1]*(self.hitResposeMult or 1)
				end
			end
		end
		
		return col1r, col1g, col1b, col1a , col2r, col2g, col2b, col2a
	end
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