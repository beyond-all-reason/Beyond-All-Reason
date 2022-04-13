-- use following format in luaui/configs/momusebindings.json
-- This implemenation allows exactly 1 command for 1 Mouse-Set
-- Only KeypressActions "p" and engine commands are supported
-- other widgets, that want to use Mouse Buttons or Wheel are ignored, when a special mousebinding exists in mousebindings.json and widget layer is above this one

--{
--   "Mouse4": {
--       "+any": ["buildfacing", "inc"]
--   },
--   "Mouse5": {
--       "+ctrl+shift": ["buildfacing", "dec"]
--   },
--   "WheelU": {
--       "+shift": ["increasespeed", ""]
--   },
--   "WheelD": {
--       "+meta": ["decreasespeed", ""],
--       "+ctrl": ["buildfacing", "inc"]
--   }
--}


-- handler needs to be true to access actionhandler functions directly !!!
function widget:GetInfo()
   return {
      name      = "Action Handler Mouse Input",
      desc      = "Bind mouse buttons(including MouseWheel)",
      author    = "Fireball",
      version   = "v1.0",
      date      = "Apr, 2022",
      license   = "GNU GPL, v3 or later",
      layer     = 100,
      enabled   = true,
      handler   = true,
   }
end

-- -------------------------------------------------------
-- settings
-- -------------------------------------------------------

-- set allowMouseWheel to false to not allow custom MouseWheel bindings at all
local allowMouseWheel = true

-- set allowMouseButtons123 to true for experiments like Shift+Ctrl+Mouse2
local allowMouseButtons123 = false

-- TODO: merge with upcoming keybindings.json file to have THE one and only centralized bindings file
local mbfile = VFS.LoadFile('luaui/configs/mousebindings.json')
local mb = Json.decode(mbfile)

-- local vars
local wheelStr
local buttonStr
local mod

-- -------------------------------------------------------
-- widget functions
-- -------------------------------------------------------

-- catch Mouse Presses
function widget:MousePress(mx, my, button)
   -- exclude buttons 1-3 for compatibility reasons
   if (not allowMouseButtons123 and button < 4) then
      return false
   end

   return MousePressAction(button)
end

-- catch Mouse Wheel Movement
-- value is ignored for now, but could be forwarded as additional parameter(opt) to keypressactions
function widget:MouseWheel(up, value)
   if not allowMouseWheel then
       return false
   end

   return MouseWheelAction(up)
end

-- -------------------------------------------------------
-- handler functions
-- -------------------------------------------------------

function MousePressAction(button)
   -- translate button(1,2,3...) to Mouse1, Mouse2, Mouse3...
   buttonStr = "Mouse" .. tostring(button)
   return ExecuteMouseBinding(buttonStr)
end

function MouseWheelAction(up)
   -- translate Up(bool) to WheelU and WheelD
   wheelStr = up and "WheelU" or "WheelD"
   return ExecuteMouseBinding(wheelStr)
end

function BuildModString()
   -- translate GetModKeyState to e.g.: "+alt" or "+ctrl+shift"
   mod = ""
   
   local alt,ctrl,meta,shift = Spring.GetModKeyState()
   if (alt) then mod = mod .. "+alt" end
   if (ctrl) then mod = mod .. "+ctrl" end
   if (meta) then mod = mod .. "+meta" end
   if (shift) then mod = mod .. "+shift" end
   
   if (mod == "") then mod = "+any" end

   return mod
end

function ExecuteMouseBinding(btn)
   -- mousebindings.json (mb)
   -- the mod ALWAYS MUST be in order +alt+ctrl+meta+shift (all other orders fail !)
   -- {
   --    "Mouse4": {
   --        "+ctrl+shift": ["buildfacing", "inc"]
   --    }
   -- }
   mod = BuildModString()
   if mb[btn][mod] then
      -- binding found, execute (returns always true = consumed)
      return ExecuteAction(mb[btn][mod][1], mb[btn][mod][2])
   end

   -- no binding found, return false (button/wheel not consumed)
   return false
end

function ExecuteAction(cmd, opt)   
   -- Try to execute our command as a lua keyPressAction "p" with no repeat and not released(=pressed)
   if widgetHandler.actionHandler:TryAction(widgetHandler.actionHandler.keyPressActions, cmd, opt, widgetHandler.actionHandler:MakeWords(opt), false, false) then
      return true
   end

   -- Otherwise send our command blindly to engine (sadly nothing is returned)
   Spring.SendCommands(cmd .. " " .. opt)
   
   -- assuming command was executed and return true
   return true
end


