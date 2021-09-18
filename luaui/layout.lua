--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    layout.lua
--  brief:   dummy and default LayoutButtons() routines
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  ConfigLayoutHandler(data) is defined at the end of this file.
--
--    data ==  true:  use DefaultHandler
--    data == false:  use DummyHandler
--    data ==  func:  use the provided function
--    data ==   nil:  use Spring's default control panel
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

include("colors.h.lua")

local langSuffix = Spring.GetConfigString('Language', 'fr')
local l10nName = 'L10N/commands_' .. langSuffix .. '.lua'
local success, translations = pcall(VFS.Include, l10nName)
if (not success) then
  translations = nil
end


local showPanelLabel = false


-- for DefaultHandler
local FrameTex   = "bitmaps/icons/frame_slate_128x96.png"
local FrameScale = "&0.1x0.1&"
local PageNumTex = "bitmaps/circularthingy.tga"


if (false) then  --  disable textured buttons?
  FrameTex   = ""
  PageNumTex = ""
end


local PageNumCmd = {
  name    = "1",
  texture = PageNumTex,
  tooltip = "Active Page Number\n(click to toggle buildiconsfirst)",
  actions = { "buildiconsfirst", "firstmenu" }
}


--------------------------------------------------------------------------------

local function DummyHandler(xIcons, yIcons, cmdCount, commands)

  widgetHandler.commands   = commands
  widgetHandler.commands.n = cmdCount
  widgetHandler:CommandsChanged()
  
  return "", xIcons, yIcons, {}, {}, {}, {}, {}, {}, {}, {}
end


--------------------------------------------------------------------------------

local function DefaultHandler(xIcons, yIcons, cmdCount, commands)

  widgetHandler.commands   = commands
  widgetHandler.commands.n = cmdCount
  widgetHandler:CommandsChanged()

  -- FIXME: custom commands  
  if (cmdCount <= 0) then
    return "", xIcons, yIcons, {}, {}, {}, {}, {}, {}, {}, {}
  end
  
  local menuName = ''
  local removeCmds = {}
  local customCmds = widgetHandler.customCommands
  local onlyTexCmds = {}
  local reTexCmds = {}
  local reNamedCmds = {}
  local reTooltipCmds = {}
  local reParamsCmds = {}
  local iconList = {}

  local cmdsFirst = (commands[1].id >= 0)

  if (showPanelLabel) then
    if (cmdsFirst) then
      menuName =   RedStr .. 'Commands'
    else
      menuName = GreenStr .. 'Build Orders'
    end
  end

  local ipp = (xIcons * yIcons)  -- iconsPerPage

  local prevCmd = cmdCount - 1
  local nextCmd = cmdCount - 0
  local prevPos = ipp - xIcons
  local nextPos = ipp - 1
  if (prevCmd >= 1) then reTexCmds[prevCmd] = FrameTex end
  if (nextCmd >= 1) then reTexCmds[nextCmd] = FrameTex end

  local pageNumCmd = -1
  local pageNumPos = (prevPos + nextPos) / 2
  if (xIcons > 2) then
    local color
    if (commands[1].id < 0) then color = GreenStr else color = RedStr end
    local activePage = activePage or 0
    local pageNum = '' .. (activePage + 1) .. ''
    PageNumCmd.name = color .. '   ' .. pageNum .. '   '
    table.insert(customCmds, PageNumCmd)
    pageNumCmd = cmdCount + 1
  end

  local pos = 0;
  local firstSpecial = (xIcons * (yIcons - 1))

  for cmdSlot = 1, (cmdCount - 2) do

    -- fill the last row with special buttons
    while ((pos % ipp) >= firstSpecial) do
      pos = pos + 1
    end
    local onLastRow = (math.abs(pos % ipp) < 0.1)

    if (onLastRow) then
      local pageStart = math.floor(ipp * math.floor(pos / ipp))
      if (pageStart > 0) then
        iconList[prevPos + pageStart] = prevCmd
        iconList[nextPos + pageStart] = nextCmd
        if (pageNumCmd > 0) then
          iconList[pageNumPos + pageStart] = pageNumCmd
        end
      end
      if (pageStart == ipp) then
        iconList[prevPos] = prevCmd
        iconList[nextPos] = nextCmd
        if (pageNumCmd > 0) then
          iconList[pageNumPos] = pageNumCmd
        end
      end
    end

    -- add the command icons to iconList
    local cmd = commands[cmdSlot]

    if ((cmd ~= nil) and (cmd.hidden == false)) then

      iconList[pos] = cmdSlot
      pos = pos + 1

      local cmdTex = cmd.texture
      if (#cmdTex > 0) then
        if (cmdTex:byte(1) ~= 38) then  --  '&' == 38
          reTexCmds[cmdSlot] = FrameScale..cmdTex..'&'..FrameTex
        end
      else
        if (cmd.id >= 0) then
          reTexCmds[cmdSlot] = FrameTex
        else
          reTexCmds[cmdSlot] = FrameScale..'#'..(-cmd.id)..'&'..FrameTex
          table.insert(onlyTexCmds, cmdSlot)
        end
      end

      if (translations) then
        local trans = translations[cmd.id]
        if (trans) then
          reTooltipCmds[cmdSlot] = trans.desc
          if (not trans.params) then
            if (cmd.id ~= CMD.STOCKPILE) then
              reNamedCmds[cmdSlot] = trans.name
            end
          else
            local num = tonumber(cmd.params[1])
            if (num) then
              num = (num + 1)
              cmd.params[num] = trans.params[num]
              reParamsCmds[cmdSlot] = cmd.params
            end
          end
        end
      end
    end
  end

  return menuName, xIcons, yIcons,
         removeCmds, customCmds,
         onlyTexCmds, reTexCmds,
         reNamedCmds, reTooltipCmds, reParamsCmds,
         iconList
end


--------------------------------------------------------------------------------

function ConfigLayoutHandler(data)
  if (type(data) == 'function') then
    LayoutButtons = data
  elseif (type(data) == 'boolean') then
    if (data) then
      LayoutButtons = DefaultHandler
    else
      LayoutButtons = DummyHandler
    end
  elseif (data == nil) then
    LayoutButtons = nil
  end

  forceLayout = true
end


LayoutButtons = DefaultHandler


--------------------------------------------------------------------------------
