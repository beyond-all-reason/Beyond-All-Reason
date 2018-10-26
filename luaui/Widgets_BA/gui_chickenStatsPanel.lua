-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Chicken Stats Panel",
    desc      = "Shows statics and progress whhen fighting vs Chickens",
    author    = "quantum",
    date      = "May 04, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = -9, 
    enabled   = true  --  loaded by default?
  }
end

local customScale = 1
local widgetScale = customScale

local teams = Spring.GetTeamList()
for i =1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
    if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 9) == 'Chicken: ' then
        chickensEnabled = true
    end
end

if chickensEnabled == true then
	Spring.Echo("[ChickenDefense: Chicken Panel] Activated!")
else
	Spring.Echo("[ChickenDefense: Chicken Panel] Deactivated!")
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not Spring.GetGameRulesParam("difficulty")) then
  return false
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetTimer        = Spring.GetTimer
local DiffTimers      = Spring.DiffTimers
local lastRulesUpdate = Spring.GetTimer()
local GetGameSeconds  = Spring.GetGameSeconds
local GetGameRulesParam = Spring.GetGameRulesParam
local Spring          = Spring
local gl, GL          = gl, GL
local widgetHandler   = widgetHandler
local math            = math
local table           = table

local displayList
local fontHandler     = loadstring(VFS.LoadFile("LuaUI/modfonts.lua"))()
local panelFont       = "LuaUI/Fonts/FreeSansBold_14"
local waveFont        = "LuaUI/Fonts/Skrawl_40"
local panelTexture    = ":n:LuaUI/Images/chickenpanel.tga"

local viewSizeX, viewSizeY = 0,0
local w               = 300
local h               = 210
local x1              = 0
local y1              = 0
local panelMarginX    = 30
local panelMarginY    = 40
local panelSpacingY   = 7
local waveSpacingY    = 7
local moving
local capture
local gameInfo
local waveY           = 800
local waveSpeed       = 0.2
local waveCount       = 0
local waveTime
local enabled
local gotScore
local scoreCount	  = 0
local queenAnger     = 0

local guiPanel --// a displayList
local updatePanel
local hasChickenEvent = false

local red             = "\255\255\001\001"
local white           = "\255\255\255\255"

local difficulties = {
    [1] = 'Very Easy',
    [2] = 'Easy',
    [3] = 'Normal',
    [4] = 'Hard',
    [5] = 'Very Hard',
    [6] = 'Epic',
    [7] = 'Custom',
    [8] = 'Survival',
}

local rules = {
  "queenTime",
  "queenAnger",
  "gracePeriod",
  "queenLife",
  "lagging",
  "difficulty",  
  "chickenCount",
  "chickenaCount",
  "chickensCount",
  "chickenfCount",
  "chickenrCount",
  "chickenwCount",
  "chickencCount",
  "chickenpCount",
  "chickenhCount",
  "chickendCount",
  "chicken_dodoCount",
  "roostCount",
  "chickenKills",
  "chickenaKills",
  "chickensKills",
  "chickenfKills",
  "chickenrKills",
  "chickenwKills",
  "chickencKills",
  "chickenpKills",
  "chickenhKills",
  "chickendKills",
  "chicken_dodoKills",
  "roostKills",
}

local waveColors = {}
waveColors[1] = "\255\184\100\255"
waveColors[2] = "\255\120\50\255"
waveColors[3] = "\255\255\153\102"
waveColors[4] = "\255\120\230\230"
waveColors[5] = "\255\100\255\100"
waveColors[6] = "\255\150\001\001"
waveColors[7] = "\255\255\255\100"
waveColors[8] = "\255\100\255\255"
waveColors[9] = "\255\100\100\255"
waveColors[10] = "\255\200\050\050"
waveColors[11] = "\255\255\255\255"

local chickenColors = {
  {"chicken",      "\255\184\100\255"},
  {"chickena",     "\255\255\100\100"},
  {"chickenh",     "\255\255\150\150"},
  {"chickens",     "\255\100\255\100"},
  {"chickenw",     "\255\184\075\200"},
  {"chicken_dodo", "\255\150\001\001"},
  {"chickenp",     "\255\250\090\090"},
  {"chickenf",     "\255\255\255\100"},
  {"chickenc",     "\255\100\255\255"},
  {"chickenr",     "\255\100\100\255"},
}

local chickenColorSet = {}
for _, t in ipairs(chickenColors) do
  chickenColorSet[t[1]] = t[2]
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


fontHandler.UseFont(panelFont)
local panelFontSize  = fontHandler.GetFontSize()
fontHandler.UseFont(waveFont)
local waveFontSize   = fontHandler.GetFontSize()

function comma_value(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

local function MakeCountString(type, showbreakdown)
  local t = {}
  local tcount = 0
  local total = 0
  local showbrackets = false
  for _, colorInfo in ipairs(chickenColors) do
    local subTotal = gameInfo[colorInfo[1]..type]
    if subTotal > 0 then
      tcount = tcount + 1
      t[tcount] = colorInfo[2]..subTotal
      total = total + subTotal
      showbrackets = true
    end
  end
  total = total + gameInfo["chickend"..type]
  if showbreakdown then
    local breakDown =  table.concat(t, white..",")..white
    if showbrackets then
      return string.format("Chickens: %d (%s)", total, breakDown)
    else
      return string.format("Chickens: %d", total)
    end
  else
    return ("Chicken Kills: " .. white .. total)
  end
end

local function updatePos(x, y)
  x1 = math.min((viewSizeX*0.94)-(w*widgetScale)/2,x)
  y1 = math.min((viewSizeY*0.89)-(h*widgetScale)/2,y)
  updatePanel = true
end

local function PanelRow(n)
  return panelMarginX, h-panelMarginY-(n-1)*(panelFontSize+panelSpacingY)
end


local function WaveRow(n)
  return n*(waveFontSize+waveSpacingY)
end


local function CreatePanelDisplayList()
  gl.PushMatrix()
  gl.Translate(x1, y1, 0)
  gl.Scale(widgetScale, widgetScale, 1)
  gl.CallList(displayList)
  fontHandler.DisableCache()
  fontHandler.UseFont(panelFont)
  fontHandler.BindTexture()
  local currentTime = GetGameSeconds()
  local techLevel = ""
  if (currentTime > gameInfo.gracePeriod) then
    if gameInfo.queenAnger < 100 then
      techLevel = "Queen Anger: " .. gameInfo.queenAnger .. "%"
    else
      techLevel = "Queen Health: " .. gameInfo.queenLife .. "%"
    end
  else
    techLevel = "Grace Period: " .. math.ceil(((currentTime - gameInfo.gracePeriod) * -1) -0.5)
  end
  fontHandler.DrawStatic(white..techLevel, PanelRow(1))
  fontHandler.DrawStatic(white..gameInfo.unitCounts, PanelRow(2))
  fontHandler.DrawStatic(white..gameInfo.unitKills, PanelRow(3))
  fontHandler.DrawStatic(white.."Burrows: "..gameInfo.roostCount, PanelRow(4))
  fontHandler.DrawStatic(white.."Burrow Kills: "..gameInfo.roostKills, PanelRow(5))
  local s = white.."Mode: "..difficulties[gameInfo.difficulty]
  if gotScore then
    fontHandler.DrawStatic(white.."Your Score: "..comma_value(scoreCount), 88, h-170)
  else
    fontHandler.DrawStatic(white.."Mode: "..difficulties[gameInfo.difficulty], 120, h-170)
  end
  gl.Texture(false)
  gl.PopMatrix()
end


local function Draw()
  if (not enabled)or(not gameInfo) then
    return
  end

  if (updatePanel) then
    if (guiPanel) then gl.DeleteList(guiPanel); guiPanel=nil end
    guiPanel = gl.CreateList(CreatePanelDisplayList)
    updatePanel = false
  end

  if (guiPanel) then
    gl.CallList(guiPanel)
  end

  if (waveMessage)  then
    local t = Spring.GetTimer()
    fontHandler.UseFont(waveFont)
    local waveY = viewSizeY - Spring.DiffTimers(t, waveTime)*waveSpeed*viewSizeY
    if (waveY > 0) then
      for i, message in ipairs(waveMessage) do
        fontHandler.DrawCentered(message, viewSizeX/2, waveY-WaveRow(i))
      end
    else
      waveMessage = nil
      waveY = viewSizeY
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function UpdateRules()
  if (not gameInfo) then
    gameInfo = {}
  end

  for _, rule in ipairs(rules) do
    gameInfo[rule] = Spring.GetGameRulesParam(rule) or 999
  end
  gameInfo.unitCounts = MakeCountString("Count", true)
  gameInfo.unitKills  = MakeCountString("Kills", false)

  updatePanel = true
end


local function MakeLine(chicken, n)
  if (n <= 0) then
    return
  end
  local humanName = UnitDefNames[chicken].humanName
  local color = chickenColorSet[chicken]
  return color..n.." "..humanName.."s"
end

function ChickenEvent(chickenEventArgs)
	if (chickenEventArgs.type == "wave") then
		if (gameInfo.roostCount < 1) then
			return
		end
		waveMessage    = {}
		waveCount      = waveCount + 1
		waveMessage[1] = "Wave "..waveCount
		waveMessage[2] = waveColors[chickenEventArgs.tech]..chickenEventArgs.number.." chickens!"
		waveTime = Spring.GetTimer()
	elseif (chickenEventArgs.type == "burrowSpawn") then
		UpdateRules()
	elseif (chickenEventArgs.type == "queen") then
		waveMessage    = {}
		waveMessage[1] = "The Queen is angered!"
		waveTime = Spring.GetTimer()
	elseif (chickenEventArgs.type == "score"..(Spring.GetMyTeamID())) then
		gotScore = chickenEventArgs.number
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
  displayList = gl.CreateList( function()
    gl.Blending(true)
    gl.Color(1, 1, 1, 1)
    gl.Texture(panelTexture)
    gl.TexRect(0, 0, w, h)
	end)

  widgetHandler:RegisterGlobal("ChickenEvent", ChickenEvent)
  UpdateRules()
  viewSizeX, viewSizeY = gl.GetViewSizes()
  local x = math.abs(math.floor(viewSizeX - 320))
  local y = math.abs(math.floor(viewSizeY - 300))
  updatePos(x, y)
end


function widget:Shutdown()
  if hasChickenEvent then
    Spring.SendCommands({"luarules HasChickenEvent 0"})
  end
  fontHandler.FreeFont(panelFont)
  fontHandler.FreeFont(waveFont)

  if (guiPanel) then gl.DeleteList(guiPanel); guiPanel=nil end

  gl.DeleteList(displayList)
  gl.DeleteTexture(panelTexture)
  widgetHandler:DeregisterGlobal("ChickenEvent")
end

function widget:GameFrame(n)
  if not(hasChickenEvent) and n > 1 then
    Spring.SendCommands({"luarules HasChickenEvent 1"})
    hasChickenEvent = true
  end
  if (n%30< 1) then
    UpdateRules()

    if (not enabled and n > 1) then
      enabled = true
    end
--	
--    queenAnger = math.ceil((((GetGameSeconds()-gameInfo.gracePeriod+gameInfo.queenAnger)/(gameInfo.queenTime-gameInfo.gracePeriod))*100) -0.5)
 
  end
  if gotScore then
    local sDif = gotScore - scoreCount
    if sDif > 0 then
      scoreCount = scoreCount + math.ceil(sDif / 7.654321)
      if scoreCount > gotScore then 
        scoreCount = gotScore 
      else
        updatePanel = true
      end
    end
  end
end


function widget:DrawScreen()
  Draw()
end


function widget:MouseMove(x, y, dx, dy, button)
  if (enabled and moving) then
    updatePos(x1 + dx, y1 + dy)
  end
end


function widget:MousePress(x, y, button)
  if (enabled and 
       x > x1 and x < x1 + (w*widgetScale) and
       y > y1 and y < y1 + (h*widgetScale)) then
    capture = true
    moving  = true
  end
  return capture
end

 
function widget:MouseRelease(x, y, button)
  if (not enabled) then
    return
  end
  capture = nil
  moving  = nil
  return capture
end


function widget:ViewResize(vsx, vsy)
  x1 = math.floor(x1 - viewSizeX)
  y1 = math.floor(y1 - viewSizeY)
  viewSizeX, viewSizeY = vsx, vsy
  widgetScale = (0.75 + (viewSizeX*viewSizeY / 10000000)) * customScale
  x1 = viewSizeX + x1+((x1/2) * (widgetScale-1))
  y1 = viewSizeY + y1+((y1/2) * (widgetScale-1))
end


local widgetScale = 1
local vsx, vsy = Spring.GetViewGeometry()

local changelogLines = {}
local totalChangelogLines = 0


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
