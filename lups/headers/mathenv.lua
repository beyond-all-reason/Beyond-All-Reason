-- $Id: mathenv.lua 3345 2008-12-02 00:03:50Z jk $
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    mathenv.lua
--  brief:   parses and processes custom lups effects params, i.e. for the positon: "x,y,z | x=1,y=2,z=x-y"
--           those params can contain any lua code like: "x,y,z | x=random(); if (x>0.5) then y=-0.5 else y=0.5 end; z=math.sin(y^2)"
--  authors: jK
--  last updated: Jan. 2008
--
--  Copyright (C) 2007,2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

local MathG = {math = math, rand = math.random, random = math.random, sin = math.sin, cos = math.cos, pi = math.pi, 
               deg = math.deg, loadstring = loadstring, assert = assert, echo = Spring.Echo};

--local cachedParsedFunctions = {}

local function Split(str, delim, maxNb)
    --// Eliminate bad cases...
    if str:find(delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0    -- No limit
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in str:gmatch(pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then break end
    end
    --// Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = str:sub(lastPos)
    end
    return result
end

local loadstring = loadstring
local char = string.char
local type = type

function ParseParamString(strfunc)
  --if (cachedParsedFunctions[strfunc]) then
  --  return cachedParsedFunctions[strfunc]
  --end

  local luaCode = "return function() "
  local vec_defs,math_defs  = {},{}

  local params = Split(strfunc or "", "|") --//split math vector components and defintion of additional params (radius etc.)

  if (type(params)=="table") then
    vec_defs  = Split(params[1], ",")
    if (params[2]) then math_defs = Split(params[2], ",") end
  else vec_defs = params end

  --// set user variables (i.e. radius of the effect)
  for i=1,#math_defs do
    luaCode = luaCode .. math_defs[i] .. ";"
  end

  --// set return values
  for i=1,#vec_defs do
    luaCode = luaCode .. "local __" .. char(64+i) .. "=" .. vec_defs[i] .. ";"
  end

  --// and now insert the return code of those to returned values
  luaCode = luaCode .. "return "
  for i=1,#vec_defs do
    luaCode = luaCode .. " __" .. char(64+i) .. ","
  end
  luaCode = luaCode .. "nil end"

  local status, luaFunc = pcall(loadstring(luaCode))

  if (not status) then
    print(PRIO_MAJOR,'LUPS: Failed to parse custom param code: ' .. luaFunc);
    return function() return 1,2,3,4 end
  end;

  --cachedParsedFunctions[strfunc] = luaFunc

  return luaFunc
end

local setmetatable = setmetatable
local setfenv = setfenv
local pcall = pcall
local meta  = {__index={}}

function ProcessParamCode(func, locals)
  --// set up safe enviroment
  meta.__index = locals
  setmetatable( MathG, meta );

  setfenv(func, MathG);

  --// run generated code
  local success,r1,r2,r3,r4 = pcall( func );
  setmetatable( MathG, nil );

  if (success) then
    return r1,r2,r3,r4;
  else
    print(PRIO_MAJOR,'LUPS: Failed to run custom param code: ' .. r1);
    return nil;
  end
end