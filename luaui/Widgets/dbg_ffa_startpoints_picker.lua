--[[
This is an in-game editor companion widget for generating FFA start points
configs expected by the **FFA start setup** gadget (`game_ffa_start_setup.lua`).
Please see `luarules/configs/ffa_startpoints/README.txt` for full details on how
this widget works.

The widget will only work in solo games (nothing but the player, not even AIs)
with dev mode and cheats enabled. It will not allow itself to run in any other
situation, including replays and singleplayer games where the player is alone
but there are AIs.
]]

local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name = "FFA start points picker",
    desc =
    "Companion widget for generating FFA start points configs as expected by the **FFA start setup** gadget (`game_ffa_start_setup.lua`)",
    author = "nbusseneau",
    date = "2023-08-20",
    license = "GPL-2.0-or-later",
    layer = 1000,   -- must run later than `cmd_bar_hotkeys` to avoid being overriden
    handler = true, -- need superpowers to disable other widgets
    enabled = false
  }
end


-- Localized functions for performance
local tableInsert = table.insert
local tableRemove = table.remove

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamUnits = Spring.GetTeamUnits

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local startPoints
local byAllyTeamCount
local startPointUnitName = "armcom"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local spGetUnitPosition = Spring.GetUnitPosition

---Potential map start point, materialized by a unit.
---@class StartPoint
local StartPoint = {}
StartPoint.__index = StartPoint

---@param unitID integer
---@return StartPoint
function StartPoint:new(unitID)
  self = setmetatable({}, self)
  self.unitID = unitID
  self.isSelected = false

  ---@return integer, integer, integer
  function StartPoint:getPosition()
    return spGetUnitPosition(self.unitID)
  end

  return self
end

function StartPoint.__eq(a, b)
  return a.unitID == b.unitID
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---Singleton sequence of all potential start points on the map, by index.
---@class StartPoints
local StartPoints = {}
StartPoints.__index = StartPoints

---@return StartPoints # singleton instance of StartPoints
function StartPoints:getInstance()
  if StartPoints.instance then
    return StartPoints.instance
  end
  self = setmetatable({}, StartPoints)
  StartPoints.instance = self

  ---@param unitID integer
  ---@return integer?, StartPoint? # index and start point if found, nil and nil otherwise
  function StartPoints:get(unitID)
    for index, startPoint in ipairs(self) do
      if startPoint.unitID == unitID then
        return index, startPoint
      end
    end
    return nil, nil
  end

  ---@param unitID integer
  ---@return boolean # true if start point was added, false otherwise
  function StartPoints:add(unitID)
    local startPoint = StartPoint:new(unitID)
    if not table.contains(self, startPoint) then
      tableInsert(self, startPoint)
      return true
    end

    return false
  end

  ---@param unitID integer
  ---@return boolean # true if start point was removed, false otherwise
  function StartPoints:remove(unitID)
    local startPoint = StartPoint:new(unitID)
    local wasRemoved = tableRemoveFirst(self, startPoint)
    if wasRemoved then
      byAllyTeamCount:removeStartPoint(startPoint)
    end
    return wasRemoved
  end

  return self
end

startPoints = StartPoints:getInstance()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---Array of X start points by their index in the StartPoints singleton,
---materializing a specific start points layout for an X-way FFA.
---@class Layout
local Layout = {}
Layout.__index = Layout

---@param unitIDs integer[] sequence of unitID
---@return Layout
function Layout:new(unitIDs)
  self = setmetatable({}, Layout)
  for _, unitID in ipairs(unitIDs) do
    local index, startPoint = startPoints:get(unitID)
    if index and startPoint then
      self[index] = startPoint
    end
  end

  function Layout:reIndex()
    local temp = {}
    for oldIndex, startPoint in pairs(self) do
      local index, _ = startPoints:get(startPoint.unitID)
      if index then
        self[oldIndex] = nil
        temp[index] = startPoint
      end
    end
    for index, startPoint in pairs(temp) do
      self[index] = startPoint
    end
  end

  return self
end

function Layout.__eq(a, b)
  local isEqual = true
  for _, startPoint in pairs(a) do
    if not table.contains(b, startPoint) then
      isEqual = false
      break
    end
  end
  return isEqual
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---Singleton array of layouts by ally team count, materializing all layouts
---available for all X-way FFAs.
---@class ByAllyTeamCount
local ByAllyTeamCount = {}
ByAllyTeamCount.__index = ByAllyTeamCount

---@return ByAllyTeamCount # singleton instance of ByAllyTeamCount
function ByAllyTeamCount:getInstance()
  if ByAllyTeamCount.instance then
    return ByAllyTeamCount.instance
  end
  self = setmetatable({}, ByAllyTeamCount)
  ByAllyTeamCount.instance = self

  ---@param layout Layout
  ---@return boolean # true if layout was added, false otherwise
  function ByAllyTeamCount:addLayout(layout)
    local allyTeamCount = table.count(layout)
    if not self[allyTeamCount] then
      self[allyTeamCount] = {}
    end

    if not table.contains(self[allyTeamCount], layout) then
      tableInsert(self[allyTeamCount], layout)
      return true
    end

    return false
  end

  ---@param layout Layout
  ---@return boolean # true if layout was removed, false otherwise
  function ByAllyTeamCount:removeLayout(layout)
    local wasRemoved
    local allyTeamCount = table.count(layout)
    if self[allyTeamCount] then
      wasRemoved = tableRemoveFirst(self[allyTeamCount], layout)
    end
    if wasRemoved then
      self:cleanEmptyIndexes()
    end
    return wasRemoved
  end

  ---@param startPoint StartPoint
  function ByAllyTeamCount:removeStartPoint(startPoint)
    for _, layouts in pairs(self) do
      for key, layout in pairs(layouts) do
        if table.contains(layout, startPoint) then
          layouts[key] = nil
        end
      end
    end

    for _, layouts in pairs(self) do
      for _, layout in pairs(layouts) do
        layout:reIndex()
      end
    end

    self:cleanEmptyIndexes()
  end

  function ByAllyTeamCount:cleanEmptyIndexes()
    for allyTeamCount, _ in pairs(self) do
      if #self[allyTeamCount] == 0 then
        self[allyTeamCount] = nil
      end
    end
  end

  return self
end

byAllyTeamCount = ByAllyTeamCount:getInstance()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---Intermediate data container materializing a config file, used to serialize
---widget data or load an external config into widget data.
---@class ConfigFile
local ConfigFile = {}
ConfigFile.__index = ConfigFile

---@param config? { startPoints: table<integer, {x: integer, z: integer}>, byAllyTeamCount: table<integer, integer[][]> } external config to load (if not provided, create a ConfigFile based on current widget data)
---@return ConfigFile
function ConfigFile:new(config)
  self = setmetatable({}, ConfigFile)
  if config then
    self.startPoints = config.startPoints
    self.byAllyTeamCount = config.byAllyTeamCount
  else
    self.startPoints = {}
    self.byAllyTeamCount = {}
    for index, startPoint in ipairs(startPoints) do
      local x, _, z = startPoint:getPosition()
      self.startPoints[index] = { x = x, z = z, }
    end
    for allyTeamCount, layouts in pairsByKeys(byAllyTeamCount) do
      self.byAllyTeamCount[allyTeamCount] = {}
      for _, layout in pairs(layouts) do
        local indexes = {}
        for index, _ in pairsByKeys(layout) do
          tableInsert(indexes, index)
        end
        tableInsert(self.byAllyTeamCount[allyTeamCount], indexes)
      end
    end
  end

  local function serializeStartPoints()
    local output = "local startPoints = {\n"
    for index, startPoint in ipairs(self.startPoints) do
      output = output .. string.format("  [%d] = { x = %d, z = %d, },\n", index, startPoint.x, startPoint.z)
    end
    return output .. "}\n\n"
  end

  local function serializeByAllyTeamCount()
    local output = "local byAllyTeamCount = {\n"
    for allyTeamCount, layouts in pairsByKeys(self.byAllyTeamCount) do
      output = output .. string.format("  -- %d-way => \n  [%d] = {\n", allyTeamCount, allyTeamCount)
      for _, indexes in pairs(layouts) do
        output = output .. string.format("    { ")
        for _, index in ipairs(indexes) do
          output = output .. string.format("%s, ", index)
        end
        output = output .. string.format("},\n")
      end
      output = output .. "  },\n\n"
    end
    output = output:sub(1, -2) -- remove extraneous newline when we reach end of byAllyTeamCount
    return output .. "}\n\n"
  end

  local function serializeReturnValues()
    return [[
return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
]]
  end

  ---Serialize into the format expected by the `game_ffa_start_setup` gadget.
  ---@return string
  function ConfigFile:serialize()
    local output = serializeStartPoints()
    output = output .. serializeByAllyTeamCount()
    return output .. serializeReturnValues()
  end

  ---Coroutine to load this ConfigFile into widget data.
  ---@return thread
  function ConfigFile:getLoadCoroutine()
    -- must use a coroutine because we need to synchronize with /give commands
    -- and wait for them to go through, so that new start points are registered
    -- before we interact with byAllyTeamCount and layouts
    return coroutine.create(function()
      for _, startPoint in ipairs(self.startPoints) do
        Spring.SendCommands(string.format("give %s @%s,%s,%s", startPointUnitName, startPoint.x, 0, startPoint.z))
        coroutine.yield()
      end
      for _, layouts in pairsByKeys(self.byAllyTeamCount) do
        for _, indexes in pairs(layouts) do
          local unitIDs = {}
          for _, index in ipairs(indexes) do
            local startPoint = startPoints[index]
            if startPoint then
              tableInsert(unitIDs, startPoint.unitID)
            end
          end
          local layout = Layout:new(unitIDs)
          byAllyTeamCount:addLayout(layout)
        end
      end
    end)
  end

  return self
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local configLoadCoroutine
local startPointUnitDefId = UnitDefNames[startPointUnitName].id

local function addStartPoint(unitID, unitDefID)
  unitDefID = unitDefID or spGetUnitDefID(unitID)
  if unitDefID == startPointUnitDefId then
    startPoints:add(unitID)
  end
end

local function initializeStartPoints(widget)
  local units = spGetTeamUnits(spGetMyTeamID())
  for _, unitID in pairs(units) do
    addStartPoint(unitID)
  end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  addStartPoint(unitID, unitDefID)

  -- handle synchronization with getLoadCoroutine() after a /give command
  if configLoadCoroutine then
    coroutine.resume(configLoadCoroutine)
    if coroutine.status(configLoadCoroutine) == "dead" then
      configLoadCoroutine = nil
    end
  end
end

local function removeStartPoint(unitID, unitDefID)
  unitDefID = unitDefID or spGetUnitDefID(unitID)
  if unitDefID == startPointUnitDefId then
    startPoints:remove(unitID)
  end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
  removeStartPoint(unitID, unitDefID)
end

function widget:SelectionChanged(selectedUnits)
  for _, startPoint in ipairs(startPoints) do
    if table.contains(selectedUnits, startPoint.unitID) then
      startPoint.isSelected = true
    else
      startPoint.isSelected = false
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local WIPConfigsDir = "LuaUI"
local WIPConfigFilePrefix = "dbg_ffa_"
local ephemeralConfig = "dbg_ffa_startpoints_picker"

local function tryLoadWIPConfig(currentMapName)
  local availableWIPConfigs = VFS.DirList(WIPConfigsDir, string.format("%s%s*.lua", WIPConfigFilePrefix, currentMapName))
  if #availableWIPConfigs > 0 then
    local lastWIPConfig = availableWIPConfigs[#availableWIPConfigs]
    Spring.Log(widget:GetInfo().name, LOG.INFO,
      string.format("found WIP config file %s previously written by editor for current map %s", lastWIPConfig,
        currentMapName))
    return VFS.Include(lastWIPConfig)
  end
  return nil
end

local function tryLoadConfigFromBAR(currentMapName)
  local sanitizedCurrentMapName = currentMapName:gsub("_", " "):lower()
  local configsDirectory = "luarules/configs/ffa_startpoints/"
  local availableConfigFiles = VFS.DirList(configsDirectory, "*.lua")

  for _, configFile in pairs(availableConfigFiles) do
    local basename = configFile:gsub(configsDirectory, ""):gsub(".lua", ""):gsub("_", " "):lower()
    if string.find(sanitizedCurrentMapName, basename) then
      Spring.Log(widget:GetInfo().name, LOG.INFO,
        string.format("found config %s provided by BAR for current map %s", configFile, currentMapName))
      return VFS.Include(configFile)
    end
  end
  return nil
end

local function doLoad(config)
  -- remove all existing startpoints
  local existingUnits = spGetTeamUnits(spGetMyTeamID())
  for _, unitID in pairs(existingUnits) do
    startPoints:remove(unitID)
  end

  local configFile = ConfigFile:new(config)
  configLoadCoroutine = configFile:getLoadCoroutine()
  coroutine.resume(configLoadCoroutine)

  -- clean up whatever was on the map before loading
  Spring.SelectUnitArray(existingUnits)
  Spring.SendCommands("remove")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local availableFilters = {
  { 3,  16 }, -- default: show all
  { 3,  6 },  -- third, 1 / 3
  { 7,  10 }, -- third, 2 / 3
  { 11, 16 }, -- third, 3 / 3
}
local currentFilter = 1

local function giveStartPoint()
  Spring.SendCommands("give " .. startPointUnitName)
end

local function removeSelectedStartPoints()
  Spring.SendCommands("remove")
end

local function addLayout()
  local selectedUnits = spGetSelectedUnits()
  -- don't consider anything less than 3-way layouts
  if #selectedUnits >= 3 then
    local layout = Layout:new(selectedUnits)
    if not byAllyTeamCount:addLayout(layout) then
      Spring.Log(widget:GetInfo().name, LOG.INFO, "layout was already registered")
    end
  else
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "must select at least 3 start points to add a layout")
  end
end

local function removeLayout()
  local selectedUnits = spGetSelectedUnits()
  if #selectedUnits >= 3 then
    local layout = Layout:new(selectedUnits)
    if not byAllyTeamCount:removeLayout(layout) then
      Spring.Log(widget:GetInfo().name, LOG.INFO, "this layout is not registered")
    end
  end
end

local function previousPage()
  currentFilter = currentFilter - 1
  if currentFilter == 0 then
    currentFilter = #availableFilters
  end
end

local function nextPage()
  currentFilter = currentFilter + 1
  if currentFilter > #availableFilters then
    currentFilter = 1
  end
end

local function copyToClipboard()
  local configFile = ConfigFile:new()
  WG[ephemeralConfig] = {
    startPoints = configFile.startPoints,
    byAllyTeamCount = configFile.byAllyTeamCount,
  }
  local output = configFile:serialize()
  Spring.SetClipboard(output)
  Spring.Log(widget:GetInfo().name, LOG.INFO, "copied to clipboard and stored ephemeral config")
end

local function resetLastCopy()
  if WG[ephemeralConfig] then
    doLoad(WG[ephemeralConfig])
  else
    Spring.Log(widget:GetInfo().name, LOG.INFO, "no ephemeral config found to reset")
  end
end

local function saveWIPConfig()
  local configFile = ConfigFile:new()
  local output = configFile:serialize()
  local count = 1
  local filepathNoExtension = string.format("%s/%s%s", WIPConfigsDir, WIPConfigFilePrefix, Game.mapName)
  local filepath = string.format("%s-%s.lua", filepathNoExtension, count)
  while VFS.FileExists(filepath) do
    count = count + 1
    filepath = string.format("%s-%s.lua", filepathNoExtension, count)
  end

  local f, err = io.open(filepath, 'w')
  if f then
    f:write(output)
    f:close()
    Spring.Log(widget:GetInfo().name, LOG.INFO, string.format("saved to WIP config file %s", filepath))
  elseif err then
    Spring.Log(widget:GetInfo().name, LOG.ERROR, err)
  end
end

local function loadWIPOrBARConfig()
  local currentMapName = Game.mapName
  local config = tryLoadWIPConfig(currentMapName) or tryLoadConfigFromBAR(currentMapName)
  if config then
    doLoad(config)
  else
    Spring.Log(widget:GetInfo().name, LOG.INFO, "no config found in WIP configs nor BAR configs for this map")
  end
end

-- for some reason actions do not get registered if not using lowercase names gg
local actions = {
  givestartpoint = { handler = giveStartPoint, keybind = "ctrl+sc_a" },
  removeselectedstartpoints = { handler = removeSelectedStartPoints, keybind = "ctrl+sc_d" },
  addlayout = { handler = addLayout, keybind = "sc_a" },
  removelayout = { handler = removeLayout, keybind = "sc_d" },
  previouspage = { handler = previousPage, keybind = "sc_q" },
  nextpage = { handler = nextPage, keybind = "sc_e" },
  copytoclipboard = { handler = copyToClipboard, keybind = "ctrl+sc_c" },
  resetlastcopy = { handler = resetLastCopy, keybind = "ctrl+sc_z" },
  savewipconfig = { handler = saveWIPConfig, keybind = "ctrl+sc_w" },
  loadwiporbarconfig = { handler = loadWIPOrBARConfig, keybind = "ctrl+sc_l" },
}

local function registerKeybinds(widget)
  for name, action in pairs(actions) do
    widgetHandler.actionHandler:AddAction(widget, name, action.handler, nil, 'p')
    Spring.SendCommands(string.format("unbindkeyset %s", action.keybind))
    Spring.SendCommands(string.format("bind %s %s", action.keybind, name))
  end
end

local function unregisterKeybinds(widget)
  for name, _ in pairs(actions) do
    widgetHandler.actionHandler:RemoveAction(widget, name)
  end
  Spring.SendCommands("keyreload")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- note to any fool wandering here: this code is UGLY, but UI sucks and this is
-- not intended as something many people will use, so I'm not going to bother
-- polishing, this is good enough
local vsx, vsy
local scaleFactor
local paddingDefault = 15
local padding

local panelLayouts = {}
local panelHotkeys = {}

local textSizeDefault = 40
local textSizeIndexes
local textSizeText
local textColorDefault = { 1, 0.65, 0, 1 }
local textColorSelected = { 0.35, 1, 0, 1 }
local textColorHeader = { 0, 0.85, 1, 1 }
local outlineSizeDefault = 7
local outlineSize
local outlineColor = { 0, 0, 0, 1 }
local outlineStrength = 10
local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font = nil

local DrawElement
local GetViewGeometry = Spring.GetViewGeometry
local IsGUIHidden = Spring.IsGUIHidden
local WorldToScreenCoords = Spring.WorldToScreenCoords
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glTranslate = gl.Translate
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix

local isUIInitialized = false

local function shutdownUI()
  gl.DeleteFont(font)
  isUIInitialized = false
end

local function initializeUI()
  vsx, vsy = GetViewGeometry()
  DrawElement = WG.FlowUI.Draw.Element
  local elementMargin = WG.FlowUI.elementMargin

  scaleFactor = vsx / 3840 -- this is my screen width, so all scaling is based off it
  padding = paddingDefault * scaleFactor
  textSizeIndexes = textSizeDefault * scaleFactor
  textSizeText = 0.75 * textSizeIndexes
  outlineSize = outlineSizeDefault * scaleFactor

  panelHotkeys.panelWidth = 15.7 * (padding + textSizeText)
  panelHotkeys.panelHeight = 5.75 * (padding + textSizeText) - padding
  panelHotkeys.px = vsx * 0.75 - panelHotkeys.panelWidth
  if WG['advplayerlist_api'] then
    local advPlayerListLeft = WG['advplayerlist_api'].GetPosition()[2]
    panelHotkeys.px = advPlayerListLeft - panelHotkeys.panelWidth - WG.FlowUI.elementMargin
  end
  panelHotkeys.py = 0
  panelHotkeys.sx = panelHotkeys.px + panelHotkeys.panelWidth
  panelHotkeys.sy = panelHotkeys.panelHeight
  panelHotkeys.centerX = panelHotkeys.px + panelHotkeys.panelWidth / 2

  panelLayouts.panelWidth = 16.6 * (padding + textSizeText)
  panelLayouts.px = vsx - panelLayouts.panelWidth
  panelLayouts.py = panelHotkeys.sy + elementMargin
  panelLayouts.sx = vsx
  panelLayouts.sy = (1 - 0.045) * vsy

  local fontfileScale = (0.5 + (vsx * vsy / 5700000)) -- MAGIC
  font = gl.LoadFont(fontfile, textSizeIndexes * fontfileScale, outlineSize * fontfileScale, outlineStrength)

  isUIInitialized = true
end

function widget:ViewResize()
  shutdownUI()
  initializeUI()
end

local function fontList(text, textColor, textSize, opts)
  font:Begin()
  font:SetTextColor(textColor)
  font:SetOutlineColor(outlineColor)
  font:Print(text, 0, 0, textSize, opts)
  font:End()
end

local function drawText(text, x, y, textColor, opts, textSize)
  textColor = textColor or textColorDefault
  opts = opts or "o"
  textSize = textSize or textSizeText
  local glList = glCreateList(fontList, text, textColor, textSize, opts)
  glPushMatrix()
  glTranslate(x, y, 0)
  glCallList(glList)
  glPopMatrix()
  glDeleteList(glList)
end

local function drawStartPoints()
  for index, startPoint in ipairs(startPoints) do
    local x, y, z = startPoint:getPosition()
    x, z = WorldToScreenCoords(x, y + 30, z)
    drawText(index, x, z, startPoint.isSelected and textColorSelected or nil, "cvo", textSizeIndexes)
  end
end

local function nextLine(x, y)
  return x + padding / 2 + textSizeText, y - padding - textSizeText
end

local function nextIndex(x)
  return x + padding + textSizeText
end

local function shouldDisplayAllyTeamCount(allyTeamCount)
  local filter = availableFilters[currentFilter]
  return allyTeamCount >= filter[1] and allyTeamCount <= filter[2]
end

local function drawByAllyTeamCount()
  local px, py, sx, sy = panelLayouts.px, panelLayouts.py, panelLayouts.sx, panelLayouts.sy

  DrawElement(px, py, sx, sy)
  local x, y = nextLine(px, sy)
  for allyTeamCount, layouts in pairsByKeys(byAllyTeamCount) do
    if shouldDisplayAllyTeamCount(allyTeamCount) then
      local text = string.format("%s-way", allyTeamCount)
      drawText(text, x - padding * 0.8, y, textColorHeader)
      x, y = nextLine(px, y)

      for _, layout in pairs(layouts) do
        for index, startPoint in pairsByKeys(layout) do
          drawText(index, x, y, startPoint.isSelected and textColorSelected or nil, "co")
          x = nextIndex(x)
        end
        x, y = nextLine(px, y)
      end
    end
  end
end

local function drawHotkeys()
  local px, py, sx, sy = panelHotkeys.px, panelHotkeys.py, panelHotkeys.sx, panelHotkeys.sy
  local centerX = panelHotkeys.centerX

  DrawElement(px, py, sx, sy)
  local x, y = nextLine(px, sy)
  drawText("Add point = Ctrl+A", x, y)
  drawText("Remove point = Ctrl+D", centerX, y)
  _, y = nextLine(x, y)
  drawText("Add layout = A", x, y)
  drawText("Remove layout = D", centerX, y)
  _, y = nextLine(x, y)
  drawText("Previous page = Q", x, y)
  drawText("Next page = E", centerX, y)
  _, y = nextLine(x, y)
  drawText("Copy = Ctrl+C", x, y)
  drawText("Reset last copy = Ctrl+Z", centerX, y)
  _, y = nextLine(x, y)
  drawText("Save WIP = Ctrl+W", x, y)
  drawText("Load WIP/BAR = Ctrl+L", centerX, y)
end

function widget:DrawScreenEffects()
  if IsGUIHidden() or not isUIInitialized then return end
  drawStartPoints()
  drawByAllyTeamCount()
  drawHotkeys()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local commanderNameTags = "Commander Name Tags"
local wasCommanderNameTagsRemoved = false

local function disableCommanderNameTags()
  -- commander name tags interfere with our UI, so we use some tricks with
  -- widgetHandler so that the widget gets disabled without getting toggled off
  -- in the user configuration
  local isCommanderNameTagsEnabled = widgetHandler:IsWidgetKnown(commanderNameTags)
  if isCommanderNameTagsEnabled then
    local commanderNameTagsWidget = widgetHandler:FindWidget(commanderNameTags)
    widgetHandler:RemoveWidget(commanderNameTagsWidget)
    wasCommanderNameTagsRemoved = true
  end
end

local function reEnableCommanderNameTags()
  if wasCommanderNameTagsRemoved then
    widgetHandler:EnableWidget(commanderNameTags)
    wasCommanderNameTagsRemoved = false
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function isSoloDevMode()
  -- compute if we are in a solo game (nothing but the player, not even AIs)
  local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
  local allyTeamList = Spring.GetAllyTeamList()
  local allyTeamCount = 0
  for _, allyTeam in ipairs(allyTeamList) do
    if allyTeam ~= gaiaAllyTeamID then
      allyTeamCount = allyTeamCount + 1
    end
  end
  local teamList = Spring.GetTeamList(Spring.GetMyAllyTeamID())
  local teamCount = table.count(teamList)
  local isSolo = allyTeamCount == 1 and teamCount == 1

  -- we only run in solo games with dev mode enabled, and not in replays
  if not isSolo or not Spring.Utilities.IsDevMode() or Spring.IsReplay() then
    return false
  end
  return true
end

local function lateInitialize(widget)
  disableCommanderNameTags()
  registerKeybinds(widget)
  initializeStartPoints(widget)
  initializeUI()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local initialFrame

function widget:Initialize()
  if not isSoloDevMode() then
    widgetHandler:RemoveWidget(self)
    return
  end

  Spring.SetLogSectionFilterLevel(widget:GetInfo().name, LOG.INFO)
  -- we register the `GameFrame` callin to defer the rest of initialization at a
  -- later time. This is a kludge to make sure that we run very late, after the
  -- `autocheat` widget has had a chance to enable cheating
  initialFrame = Spring.GetGameFrame()
  widgetHandler:UpdateWidgetCallIn('GameFrame', self);
end

function widget:GameFrame(f)
  if f > initialFrame + 10 then
    widgetHandler:RemoveWidgetCallIn('GameFrame', self);

    if not Spring.IsCheatingEnabled() then
      Spring.Log(widget:GetInfo().name, LOG.ERROR, "this widget needs cheating enabled")
      widgetHandler:RemoveWidget(self)
      return
    end

    lateInitialize(self)
  end
end

function widget:Shutdown()
  reEnableCommanderNameTags()
  unregisterKeybinds(self)
  shutdownUI()
end
