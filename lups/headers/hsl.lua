-- $Id: hsl.lua 3171 2008-11-06 09:06:29Z det $
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    hsl.h.lua
--  brief:   hsl colorspace class
--  authors: jK
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

local max  = math.max
local min  = math.min
local type = type

HSL = {}
local mt = {}
mt.__index = mt

function mt:setRGB(r,g,b)
  local cmin = min(r,g,b)
  local cmax = max(r,g,b)

  local dm = cmax-cmin
  local dp = cmax+cmin
  self.L = (dp)*0.5

  if (d==0) then
     self.H,self.S=0,0
  else
    if (self.L<0.5) then 
      self.S = dm/(dp)
    else
      self.S = dm/(2 - dp)
    end

    dm = 1/dm
    if (r == cmax) then
      self.H = (g - b)*dm
    else
      if (g == cmax) then
        self.H  = 2 + (b - r)*dm
      else
        self.H = 4 + (r - g)*dm
      end
    end

    self.H = self.H*0.167
    self.H = self.H%1
  end
end

local function Hue2RGB( v1, v2, vH )
   vH=vH%1
   if     ((6*vH)<1) then
     return v1 + (v2-v1)*6*vH
   elseif ((2*vH)<1) then
     return v2
   elseif ((3*vH)<2) then
     return v1 + (v2-v1)*(0.6666 - vH)*6
   else
     return v1
   end
end

function mt:getRGB()
  if (self.S==0) then
    return {self.L,self.L,self.L}
  else
    local v2
    if (self.L<0.5) then
      v2 = self.L*(1+self.S)
    else
      v2 = (self.L+self.S) - (self.S*self.L)
    end

    local v1 = 2*self.L - v2

    return {Hue2RGB( v1, v2, self.H+0.3333 ),
            Hue2RGB( v1, v2, self.H ),
            Hue2RGB( v1, v2, self.H-0.3333 )}
  end
end

function HSL.new(r,g,b)
  local v = {H=0,S=0,L=0}
  setmetatable(v, mt)
  v:setRGB(r,g,b)
  return v
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------