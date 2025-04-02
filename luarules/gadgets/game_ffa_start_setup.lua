--[[
This gadget is responsible for setting up start points and start boxes in FFA
and TeamFFA games. Please see `luarules/configs/ffa_startpoints/README.txt` for
full details on the why and how of this gadget.

The gadget will only be enabled in FFA / TeamFFA games, and only in a synced
context, and runs in one-shot before disabling itself.
]]

if not Spring.Utilities.Gametype.IsFFA() or not gadgetHandler:IsSyncedCode() then
  return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name = 'FFA start setup',
    desc = 'Set up start points and start boxes for FFA and TeamFFA games',
    author = 'nbusseneau',
    date = '2023-08-19',
    license = 'GPL-2.0-or-later',
    layer = -1000, -- should run before anything else needs to call `GetAllyTeamStartBox`
    enabled = true
  }
end

-- set default logging to INFO since it's kinda important to know when this
-- gadget does things with start points and start boxes
Spring.SetLogSectionFilterLevel(gadget:GetInfo().name, LOG.INFO)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function tryLoadConfigFromBAR(currentMapName)
  local sanitizedCurrentMapName = currentMapName:gsub("_", " "):lower()
  local configsDirectory = "luarules/configs/ffa_startpoints/"
  local availableConfigFiles = VFS.DirList(configsDirectory, "*.lua")

  for _, configFile in pairs(availableConfigFiles) do
    local basename = configFile:gsub(configsDirectory, ""):gsub(".lua", ""):gsub("_", " "):lower()
    if string.find(sanitizedCurrentMapName, basename) then
      Spring.Log(gadget:GetInfo().name, LOG.INFO,
        string.format("found FFA start points config %s provided by BAR for current map %s", configFile, currentMapName))
      return VFS.Include(configFile), true
    end
  end
  return nil, false
end

local function tryLoadConfigFromMap(currentMapName)
  local configFile = "luarules/configs/ffa_startpoints.lua"
  if VFS.FileExists(configFile) then
    Spring.Log(gadget:GetInfo().name, LOG.INFO,
      string.format("found FFA start points config %s provided by current map %s", configFile,
        currentMapName))
    return VFS.Include(configFile), true
  end
  return nil, false
end

local function tryLoadConfig(currentMapName, requiredStartPointCount)
  -- first, try to use the FFA start points config provided by BAR for current map, if available
  local config, found = tryLoadConfigFromBAR(currentMapName)
  -- failing that, try to use the FFA start points config provided by the map itself, if available
  if not found then
    config, found = tryLoadConfigFromMap(currentMapName)
  end
  if not found then
    Spring.Log(gadget:GetInfo().name, LOG.INFO,
      string.format("did not find a FFA start points config for current map %s", currentMapName))
    return nil
  end

  local layout = nil

  -- backwards compatibility layer
  -- Previously, FFA start points configs were setting a "ffaStartPoints" global variable themselves, with logic
  -- duplicated in every file. We now properly pass local variables up the stack via VFS.Include and handle logic only
  -- here, but we also add additional backwards compatibility logic in case any such legacy start points config exists
  -- in the wild.
  if ffaStartPoints and ffaStartPoints[requiredStartPointCount] then
    Spring.Log(gadget:GetInfo().name, LOG.WARNING,
      string.format("backwards compatibility layer: using legacy FFA start points config for %s start points",
        requiredStartPointCount))
    layout = ffaStartPoints[requiredStartPointCount]
  end

  -- if a FFA start points config file has been found and a layout for the required number of start points is available
  if config and config.startPoints and config.byAllyTeamCount and config.byAllyTeamCount[requiredStartPointCount] then
    Spring.Log(gadget:GetInfo().name, LOG.INFO,
      string.format("using FFA start points config for %s start points", requiredStartPointCount))

    -- pick a random layout from the ones available
    local layouts = config.byAllyTeamCount[requiredStartPointCount]
    local randomLayout = math.random(#(layouts))

    -- map actual start points to the layout indexes
    layout = {}
    for i, startPointId in ipairs(layouts[randomLayout]) do
      local startPoint = config.startPoints[startPointId]
      layout[i] = { x = startPoint.x, z = startPoint.z }
    end
  end

  if not layout then
    Spring.Log(gadget:GetInfo().name, LOG.INFO,
      string.format("did not find a layout for %s start points for current map %s", requiredStartPointCount,
        currentMapName))
    return nil
  elseif #layout ~= requiredStartPointCount then
    Spring.Log(gadget:GetInfo().name, LOG.ERROR,
      string.format("incorrect number of start points found in layout (actual: %s, expected: %s)",
        #layout, requiredStartPointCount))
    Spring.Log(gadget:GetInfo().name, LOG.ERROR, "FFA start points config is malformed and will NOT be used")
    return nil
  else
    return layout
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function setFFAStartPoints(allyTeamList)
  -- try to find FFA start points for current map and desired number of start points
  -- if found, try and get the layout matching the desired number of start points
  local layout = tryLoadConfig(Game.mapName, #allyTeamList)

  if layout then
    table.shuffle(layout)

    -- map layout to a list of start points for ally teams, and set it up in GG
    -- for `game_initial_spawn` to use later when spawning units
    GG.ffaStartPoints = {}
    for i, allyTeamID in ipairs(allyTeamList) do
      GG.ffaStartPoints[allyTeamID] = layout[i]
    end

    Spring.Log(gadget:GetInfo().name, LOG.INFO,
      "set up start points from FFA start points config for current map")
  end
end

local function shuffleStartBoxes(allyTeamList)
  local startBoxes = {}
  for _, allyTeamID in pairs(allyTeamList) do
    local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(allyTeamID)
    startBoxes[allyTeamID] = { xmin, zmin, xmax, zmax }
  end

  table.shuffle(startBoxes, 0)

  for _, allyTeamID in pairs(allyTeamList) do
    local xmin, zmin, xmax, zmax = unpack(startBoxes[allyTeamID])
    Spring.SetAllyTeamStartBox(allyTeamID, xmin, zmin, xmax, zmax)
  end

  Spring.Log(gadget:GetInfo().name, LOG.INFO,
    "shuffled start boxes for ally teams (humans and AIs, but not Raptors and Scavengers)")
end

function gadget:Initialize()
  -- list of ally teams (humans and AIs, but not Raptors and Scavengers)
  local allyTeamList = Spring.Utilities.GetAllyTeamList()

  setFFAStartPoints(allyTeamList)
  if Spring.GetModOptions().teamffa_start_boxes_shuffle then
    shuffleStartBoxes(allyTeamList)
  end

  -- our job here is done :)
  gadgetHandler:RemoveGadget(self)
end
