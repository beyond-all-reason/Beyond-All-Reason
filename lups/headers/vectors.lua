-- $Id: vectors.lua 3171 2008-11-06 09:06:29Z det $
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    vectors.h.lua
--  brief:   collection of some usefull vector functions (length, addition, skmult, vmult, ..)
--  authors: jK
--  last updated: 30 Oct. 2007
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

local sqrt = math.sqrt
local min  = math.min
local type = type

Vector = {}
Vector.mt = {}

function Vector.new (t)
  local v = {}
  setmetatable(v, Vector.mt)
  for i,w in pairs(t) do v[i] = w end
  return v
end

function Vector.mt.__add(a,b)
  if type(a) ~= "table" or
     type(b) ~= "table"
  then
     error("attempt to `add' a vector with a non-table value", 2)
  end

  local v = {}
  local n = math.min(#a or 0,#b or 0)
  for i=1,n do v[i] = a[i]+b[i] end
  return v
end

function Vector.mt.__sub(a,b)
  if type(a) ~= "table" or
     type(b) ~= "table"
  then
     error("attempt to `sub' a vector with a non-table value", 2)
  end

  local v = {}
  local n = math.min(#a or 0,#b or 0)
  for i=1,n do v[i] = a[i]-b[i] end
  return v
end

function Vector.mt.__mul(a,b)
  if ((type(a) ~= "table") and (type(b) ~= "number"))or
     ((type(b) ~= "table") and (type(a) ~= "number"))
  then
     error("attempt to `mult' a vector with something else than a number", 2)
  end

  local u,w
  if (type(a) == "table") then
    u,w = a,b
  else
    u,w = b,a
  end

  local v = {}
  for i=1,#u do v[i] = w*u[i] end
  return v
end



function Vadd(a,b)
  local v = {}
  local n = min(#a or 0,#b or 0)
  for i=1,n do v[i] = a[i]+b[i] end
  return v
end

function Vsub(a,b)
  local v = {}
  local n = min(#a or 0,#b or 0)
  for i=1,n do v[i] = a[i]-b[i] end
  return v
end

function Vmul(a,b)
  local u,w
  if (type(a) == "table") then
    u,w = a,b
  else
    u,w = b,a
  end

  local v = {}
  for i=1,#u do v[i] = w*u[i] end
  return v
end

function Vcross(a,b)
  return {a[2]*b[3] - a[3]*b[2],
          a[3]*b[1] - a[1]*b[3],
          a[1]*b[2] - a[2]*b[1]}
end

function Vlength(a)
  return sqrt(a[1]*a[1] + a[2]*a[2] + a[3]*a[3])
end

function CopyVector(write,read,n)
  for i=1,n do
    write[i]=read[i]
  end
end

function CreateEmitMatrix3x3(x,y,z)
  local xz = x*z
  local xy = x*y
  local yz = y*z

  return { 
    x*x,  xy-z, xz+y,
    xy+z, y*y,  yz-x,
    xz-y, yz+x, z*z
  }
end

function MultMatrix3x3(m, x,y,z)
  return m[1]*x + m[2]*y + m[3]*z,
         m[4]*x + m[5]*y + m[6]*z,
         m[7]*x + m[8]*y + m[9]*z
end