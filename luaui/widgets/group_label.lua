--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    group_label.lua
--  brief:   displays label on units in a group
--  author:  gunblob
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Group Label",
    desc      = "Displays label on units in a group",
    author    = "gunblob",
    date      = "June 12, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local textColor = {0.7, 1.0, 0.7, 1.0}
local textSize = 12.0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Rendering
--

function widget:DrawWorld()
   local groups = Spring.GetGroupList()
   for group, _ in pairs(groups) do
      units = Spring.GetGroupUnits(group)
      for _, unit in ipairs(units) do
         if Spring.IsUnitInView(unit) then
            local ux, uy, uz = Spring.GetUnitViewPosition(unit)
            gl.PushMatrix()
            gl.Translate(ux, uy, uz)
            gl.Billboard()
            gl.Color(textColor)
            gl.Text("" .. group, -10.0, -15.0, textSize, "cn")
            gl.PopMatrix()
         end
      end
   end
end
