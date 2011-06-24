
function widget:GetInfo()
  return {
    name      = "Old BA Layout",
    desc      = "Sets the control panel to BA default",
    author    = "jK and trepan, mixed by lurker",
    date      = "Feb 3, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = -10,
    handler   = true,
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

include("colors.h.lua")

local langSuffix = Spring.GetConfigString('Language', 'fr')
local l10nName = 'L10N/commands_' .. langSuffix .. '.lua'
local success, translations = pcall(VFS.Include, l10nName)
if (not success) then
  translations = nil
end

-- for DefaultHandler
local FrameTex   = "bitmaps/icons/frame_slate_128x96.png"
local FrameScale     = "&0.099x0.132&"
local PageNumTex = "bitmaps/circularthingy.tga"


if (false) then  --  disable textured buttons?
  FrameTex   = "false"
  PageNumTex = "false"
end

local PageNumCmd = {
  name     = "1",
  iconname = PageNumTexture,
  tooltip  = "Active Page Number\n(click to toggle buildiconsfirst)",
  actions  = { "buildiconsfirst", "firstmenu" }
}

if (Game.version:find("0.75")==nil)or(Game.version:find("svn")) then
  PageNumCmd.texture  = PageNumCmd.iconname
  PageNumCmd.iconname = nil
end

--------------------------------------------------------------------------------

local function CustomLayoutHandler(xIcons, yIcons, cmdCount, commands)

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

--[[  local cmdsFirst = (commands[1].id >= 0)
  if (cmdsFirst) then
    menuName =   RedStr .. 'Commands'
  else
    menuName = GreenStr .. 'Build Orders'
  end -- it doesn't really make sense on large pages]]

  local ipp = (xIcons * yIcons)  -- iconsPerPage

  local activePage = Spring.GetActivePage()

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
    while (math.fmod(pos, ipp) >= firstSpecial) do
      pos = pos + 1
    end
    local onLastRow = (math.abs(math.fmod(pos, ipp)) < 0.1)

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

      local cmdTex = cmd.texture or "" -- FIXME 0.75b2 compatibility

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
--------------------------------------------------------------------------------

function widget:Initialize()
  for i, widget in ipairs(widgetHandler.widgets) do
    if (widget:GetInfo().name == 'Red Build/Order Menu') then
       Spring.SendCommands{"luaui disablewidget Red Build/Order Menu"}
    end
  end
  --Set up mod-custom ctrlpanel
  Spring.SendCommands({"ctrlpanel " .. LUAUI_DIRNAME .. "Configs/ctrlpanel.txt"})
  widgetHandler:ConfigLayoutHandler(CustomLayoutHandler)
end

function widget:Shutdown()
  Spring.SendCommands({"ctrlpanel " .. LUAUI_DIRNAME .. "ctrlpanel.txt"})
  widgetHandler:ConfigLayoutHandler(true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
