--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    dbg_profiler.lua
--  brief:   shows the duration of widget callins
--  author:  Jan Holthusen
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Profiler",
    desc      = "Shows the duration of widget callins",
    author    = "MelTraX",
    date      = "2007-10-09",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false,  --  loaded by default?
    handler   = true
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local callins     = { "Update", "DrawScreen", "DrawWorld", "DrawWorldPreUnit" }
local showDetails = true

local font        = "FreeMonoBold"
local fontsize    = 12

local xStep       = 140
local barWidth    = 100

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widgets = {}
local calltime = {}
local percall = {}
local calls = {}
local totals = {}
local oldFunctions = {}

local function Format(newNumber)
  if type(newNumber) ~= "number" then return newNumber end
  local SI_prefixes = { "y", "z", "a", "f", "p", "n", "u", "m", "", "k", "M", "G", "T", "P", "E", "Z", "Y" }

  local newString = "Are you kidding?"
  if math.abs(newNumber) < 10^27 and math.abs(newNumber) > 10^-27 or newNumber == 0 then
    local newNumber = math.abs(newNumber)
    local logNumber = newNumber == 0 and 0 or math.log(newNumber)/math.log(10)
    local suffix    = newNumber == 0 and 0 or math.floor(logNumber/3)
    local number    = (newNumber + (0.5*10^(math.floor(logNumber)-2))) / 10^(suffix*3)
    local fNumber   = string.sub(number, 1, tonumber(number) > 100 and 3 or 4)
    newString       = fNumber .. SI_prefixes[suffix+9]
  end

  return newString
end

local function HookCallin(widget, callin)
  oldFunctions[widget][callin] = widget[callin]
  if oldFunctions[widget][callin] ~= nil then
    calltime[widget][callin] = 0
    percall[widget][callin] = 0
    calls[widget][callin] = 0
    widget[callin] = function(...)
      local startTime = os.clock()
      returnValues = {oldFunctions[widget][callin](...)}
      calls[widget][callin] = calls[widget][callin] + 1
      calltime[widget][callin] = calltime[widget][callin] + os.clock() - startTime
      totals[widget] = totals[widget] + os.clock() - startTime
      percall[widget][callin] = calltime[widget][callin] / calls[widget][callin]
      return unpack(returnValues)
    end
  end
end

function widget:Update()
  for _,w in ipairs(widgetHandler.widgets) do
    if w.whInfo.name ~= self:GetInfo().name then
      table.insert(widgets, w)
      oldFunctions[w] = {}
      calltime[w] = {}
      percall[w] = {}
      calls[w] = {}
      totals[w] = 0
      for _,c in ipairs(callins) do
        calltime[w][c] = "--"
        percall[w][c] = "--"
        HookCallin(w, c)
      end
    end
  end
  table.sort(widgets, function(w1, w2)
    return w1.whInfo.name > w2.whInfo.name
  end)
  widgetHandler:RemoveWidgetCallIn("Update", self)
end

function widget:DrawScreen()
  local screenW, screenH = widgetHandler:GetViewSizes()
  local xPos     = (screenW - #callins*xStep + xStep + barWidth) / 2
  if not showDetails then
    xPos         = (screenW + xStep + barWidth) / 2
  end
  local yPos     = (screenH - (#widgets+1)*(fontsize+2)) / 2

  fontHandler.UseFont(":n:LuaUI/Fonts/" .. font .. "_" .. fontsize)
  local maximum = 0
  for _,t in pairs(totals) do
    maximum = math.max(maximum, t)
  end
  if showDetails then
    -- draw callin names
    gl.Color(1,1,0)
    for c=1,#callins do
      fontHandler.DrawRight(callins[c], xPos+xStep*c, yPos+20+(fontsize+2)*#widgets)
    end
  end
  gl.Color(1,1,1)
  for w=1,#widgets do
    if maximum > 0 then
      -- draw bar
      gl.Rect(xPos-xStep-10-totals[widgets[w]]/maximum*barWidth, yPos-1+(fontsize+2)*w, xPos-xStep-10, yPos+9+(fontsize+2)*w)
    end
    -- draw widget name
    gl.Color(0,1,1)
    fontHandler.Draw(widgets[w].whInfo.name, xPos-xStep, yPos+(fontsize+2)*w)
    -- draw numbers
    gl.Color(1,1,1)
    if showDetails then
      for c=1,#callins do
        fontHandler.DrawRight(Format(percall[widgets[w]][callins[c]]), xPos+xStep*(c-0.5), yPos+(fontsize+2)*w)
        fontHandler.DrawRight(Format(calltime[widgets[w]][callins[c]]), xPos+xStep*c, yPos+(fontsize+2)*w)
      end
    end
  end
end

function widget:Shutdown()
  for _,w in ipairs(widgets) do
    for _,c in ipairs(callins) do
      w[c] = oldFunctions[w][c]
    end
  end
end
