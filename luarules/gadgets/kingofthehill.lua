-----------------------------------------------------------------------------------------------
--
-- Copyright 2024
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the “Software”), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
-- the Software, and to permit persons to whom the Software is furnished to do so,
-- subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
-- FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
-- COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
-- IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-----------------------------------------------------------------------------------------------
--
-- Name: King of the Hill
-- Description: This gadget modifies the game behavior for the king of the hill game mode when it is enabled
-- Author: Saul Goodman
--
-----------------------------------------------------------------------------------------------
--
-- Documentation
--
-- This gadget adds the synced functionality for a King of the Hill game mode. In this game mode,
-- an ally team wins by spending a certain amount of time as "king". The hill is a
-- configurable circular or square cylinder on the map. An ally team becomes the king by
-- being the only team with "capture-qualified units" in the hill for a configurable
-- amount of time. Capture-qualified units are a set of units that are
-- capable of capturing the hill. Additionally, any ally team
-- is granted global line-of-sight (globalLOS) for the period that it spends as the king.
-- If the respective mod-option is enabled, ally teams may only
-- build buildings inside of their start box and the hill when they are king.
-- Moreover, when an ally team loses the throne (transitions from king to not-king) all
-- buildings belonging to that team in the hill are exploded.
--
-- The main game logic takes place in the gadget:GameFrame method. Every couple of frames,
-- it checks where all capture-qualified units are and determines what the game state
-- should be based on what teams are in and out of the hill.
--
-- The time that each ally team has been king is tracked in a table containing the number
-- of frames for which they have been king. The time for which the current king has been king
-- is not included in this table. Instead, the frame at which the current king became king is
-- stored and the table is updated when the king changes.
-- Moreover, for the team currently capturing the hill, the frame at which the capturing will
-- be complete is stored along with the direction of the capture (whether they are capturing
-- or losing the hill).
--
-- There are a number of classes used in this gadget which are explained below.
-- Set:
--   The set class is just a collection of stuff. It mimics the Java Set class.
-- RulesParamDataWrapper:
--   A class that wraps any variable that is shared with the client (UI widget) about the game state.
--   The purpose of this class is to avoid sending data to the client if it is not necessary (if it
--   has not changed value).
-- MapArea:
--   Defines an area on the map such as a startbox or the hill region. This class has subclasses
--   for each shape.
-- RectMapArea:
--   A subclass of MapArea for rectangular areas.
-- CircleMapArea:
--   A subclass of MapArea for circular areas.
--
-- Goals (TODO)
--
--   Figure out a way to have global LOS just inside the hill
--     Would be possible for circular hills with some sort of unit that gives LOS, but that
--     would not work for rectangular hills
--
--   Handle saved games
--
--   Add GG api functions for game state manipulation
--
-----------------------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "King of the Hill",
		desc = "Adds functionality for King of the Hill game mode.",
		author = "Saul Goodman",
		date = "2024",
		license = "MIT",
		layer = 0,
		enabled = true
	};
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

-- #region Global Constants and Functions
local Spring = Spring
local Game = Game
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local squareSize = Game.squareSize
local UnitDefs = UnitDefs
local UnitDefNames = UnitDefNames
local fps = Game.gameSpeed
local dayFrames = fps * 24 * 60 * 60
-- #endregion

-- /////////////////////////////
-- #region     Utils
-- /////////////////////////////

-- ---- Util Classes ----
-- ----------------------

--A Set class based on the Java API Set
local Set = {
	mt = {}
}
Set.mt.__index = Set
function Set.new()
	local set = {size = 0, elements = {}}
	setmetatable(set, Set.mt)
	return set
end
function Set:add(element)
	if not self.elements[element] then
		self.elements[element] = true
		self.size = self.size + 1
	end
end
function Set:addAll(...)
	for _, value in ipairs({...}) do
		self:add(value)
	end
end
function Set:remove(element)
	if self.elements[element] then
		self.elements[element] = nil
		self.size = self.size - 1
	end
end
function Set:removeAll(...)
	for _, value in ipairs({...}) do
		self:remove(value)
	end
end
function Set:retain(...)
	local newElements = {}
	local newSize = 0
	for _, value in ipairs({...}) do
		if self.elements[value] then
			newElements[value] = true
			newSize = newSize + 1
		end
	end
	self.elements = newElements
	self.size = newSize
end
function Set:contains(element)
	return self.elements[element]
end
function Set:containsAll(...)
	for _, value in ipairs({...}) do
		if not self.elements[value] then
			return false
		end
	end
	return true
end
function Set:clear()
	self.elements = {}
	self.size = 0
end
function Set:iter()
	return function (invariantState, controlVariable)
		local element = next(invariantState, controlVariable)
		return element
	end, self.elements, nil
end
function Set:unpack(lastElement)
	local nextElement = next(self.elements, lastElement)
	if nextElement ~= nil then
		return nextElement, self:unpack(nextElement)
	end
end

--A class that wraps a data value and sets its rules param only when it changes
local RulesParamDataWrapper = {
	mt = {}
}
RulesParamDataWrapper.mt.__index = RulesParamDataWrapper
function RulesParamDataWrapper.new(args)
	if not args.paramName then
		error("Missing one or more arguments for new RulesParamDataWrapper", 2)
	end
	setmetatable(args, RulesParamDataWrapper.mt)
	args:set(args.value)
	args:forceSend()--force send so that initial nil values are sent when gadget is reloaded
	return args
end
-- Sets the value but does not send it
function RulesParamDataWrapper:set(value)
	self.value = value
end
-- Sends the value no matter what
function RulesParamDataWrapper:forceSend()
	Spring.SetGameRulesParam(self.paramName, self.value)
	self.lastSentValue = self.value
end
-- Sends the value if it is different from the last sent value
function RulesParamDataWrapper:send()
	if self.value ~= self.lastSentValue then
		self:forceSend()
	end
end
-- Sets the value and sends it if it is different from the last sent value
function RulesParamDataWrapper:setAndSend(value)
	self:set(value)
	self:send()
end

-- ---- Util Functions & Variables ----
-- ------------------------------------

local tonumber = tonumber

local string = string

local math = math

table.unpack = table.unpack or unpack

local table = table

local function distance(x1, z1, x2, z2)
	return math.sqrt((x2-x1)^2 + (z2-z1)^2)
end

-- copied from https://stackoverflow.com/a/7615129
local function splitStr(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

--Converts tables into strings. For debugging only. Copied from https://stackoverflow.com/a/27028488
local function dump(o)
	if type(o) == 'table' then
	   local s = '{ '
	   for k,v in pairs(o) do
		  if type(k) ~= 'number' then k = '"'..k..'"' end
		  s = s .. '['..k..'] = ' .. dump(v) .. ','
	   end
	   return s .. '} '
	else
	   return tostring(o)
	end
 end

-- /////////////////////////////
-- #endregion  Utils
-- /////////////////////////////

-- #region Hill Area Classes
-- These classes define the hill area and provide general methods such as isInside(x,y) for various shapes (circle and square)

local MapArea = {
	mt = {}
}
MapArea.mt.__index = MapArea
function MapArea.new(args)
	args = args or {}
	setmetatable(args, MapArea.mt)
	return args
end

local RectMapArea = {
	mt = {}
}
setmetatable(RectMapArea, MapArea.mt)
RectMapArea.mt.__index = RectMapArea
function RectMapArea.new(args)
	if not args.left or not args.right or not args.top or not args.bottom then
		error("Missing one or more arguments for new RectMapArea", 2)
	end
	args.type = args.type or "rect"
	args = MapArea.new(args)
	setmetatable(args, RectMapArea.mt)
	return args
end
function RectMapArea:isPointInside(x, z)
	return x >= self.left and x <= self.right and z <= self.bottom and z >= self.top
end
function RectMapArea:isBuildingInside(x, z, sizeX, sizeZ)
	local top, right, bottom, left = z - sizeZ/2, x + sizeX/2, z + sizeZ/2, x - sizeX/2
	--Spring.Log("KingoftheHill", "error", "x: " .. x .. " z: " .. z .. " sizeX: " .. sizeX .. " sizeZ: " .. sizeZ .. " l: " .. left .. " t: " .. top .. " r: " .. right .. " b: " .. bottom)
	return top >= self.top and right <= self.right and bottom <= self.bottom and left >= self.left
end
function RectMapArea:getUnitsInside()
	return Spring.GetUnitsInRectangle(self.left, self.top, self.right, self.bottom)
end

local CircleMapArea = {
	mt = {}
}
setmetatable(CircleMapArea, MapArea.mt)
CircleMapArea.mt.__index = CircleMapArea
function CircleMapArea.new(args)
	if not args.x or not args.z or not args.radius then
		error("Missing one or more arguments for new CircleMapArea", 2)
	end
	args.type = args.type or "circle"
	args = MapArea.new(args)
	setmetatable(args, CircleMapArea.mt)
	return args
end
function CircleMapArea:isPointInside(x, z)
	return distance(x, z, self.x, self.z) <= self.radius
end
function CircleMapArea:isBuildingInside(x, z, sizeX, sizeZ)
	local top, right, bottom, left = z - sizeZ/2, x + sizeX/2, z + sizeZ/2, x - sizeX/2
	return self:isPointInside(left, top) and self:isPointInside(right, top) and self:isPointInside(right, bottom) and self:isPointInside(left, bottom)
end
function CircleMapArea:getUnitsInside()
	return Spring.GetUnitsInCylinder(self.x, self.z, self.radius)
end

-- #endregion

-- #region Configuration Constants

--Defines the maximum value of the coordinate system used in the hill area mod options
local mapAreaScale = 200

--Defines the default hill area used if the mod option string is invalid
local defaultHillArea = RectMapArea.new{left = 75*mapSizeX/mapAreaScale, right = 125*mapSizeX/mapAreaScale, top = 125*mapSizeZ/mapAreaScale, bottom = 75*mapSizeZ/mapAreaScale}

--Defines a set of unit def ids that are capable of capturing the hill (currently all commanders)
local captureQualifiedUnitNames = {
	"armcom", "armcomboss", "armcomlvl2", "armcomlvl3", "armcomlvl4", "armcomlvl5",
	"armcomlvl6", "armcomlvl7", "armcomlvl8", "armcomlvl9", "armcomlvl10", "corcom", "corcomboss", "corcomlvl2",
	"corcomlvl3", "corcomlvl4", "corcomlvl5", "corcomlvl6", "corcomlvl7", "corcomlvl8", "corcomlvl9", "corcomlvl10",
	"legcom", "legcomecon", "legcomdef", "legcomoff", "legcomt2def", "legcomt2off", "legcomt2com", "legcomlvl2",
	"legcomlvl3", "legcomlvl4", "legcomlvl5", "legcomlvl6", "legcomlvl7", "legcomlvl8", "legcomlvl9", "legcomlvl10"
}
local captureQualifiedUnitDefIds = Set.new()
for _, unitName in ipairs(captureQualifiedUnitNames) do
	local unitDef = UnitDefNames[unitName]
	if unitDef then--prevent adding units that are not loaded
		captureQualifiedUnitDefIds:add(unitDef.id)
	end
end

--Defines the number of frames per each update of KOTH related states (see gadget:gameFrame below)
local framesPerUpdate = 6

-- #endregion

-- #region Mod Options

-- the MapArea defining the hill
local hillArea

-- whether or not players can build outside of their start area or the captured hill
local buildOutsideBoxes

-- the total time needed as king to win in milliseconds
local winKingTime

-- winKingTime in frames
local winKingTimeFrames

-- the number of milliseconds an ally team must occupy the hill to capture it
local captureDelay

-- captureDelay in frames
local captureDelayFrames

-- health multiplier for capture qualified units
local healthMultiplier

-- whether the king has globalLOS
local kingGlobalLos

-- whether units are immune to damage in their start boxes
local noDamageInBoxes

-- whether all units in the hill will explode when the king changes
local explodehillunits

-- #endregion

-- #region Main Variables
-- These variables store the dynamic data needed for the main functionality of this gadget

-- teamId to allyTeamId for all teams (faster than calling Spring functions every time a team's allyTeam is needed)
local teamToAllyTeam = {}

-- unitId to allyTeamId for all capture-qualified units
-- stores the set of all capture-qualified units and provides easy way to get their corresponding allyTeam
local captureQualifiedUnits = {}

-- allyTeamId to RectMapArea defining the allyTeam's starting area (faster than calling Spring functions every time start area is needed)
local startBoxes = {}

-- allyTeamId to number of alive member teams
-- used to keep track of when an entire ally team dies so it can be disqualified
local allyTeamLives = {}

-- Set of unitIds for all buildings built by the current king ally team in the hill area
-- Used to explode all buildings when the current king loses the throne
local hillBuildings = Set.new()

-- the allyTeamId of the ally team that is currently king or nil if there is no king
local kingAllyTeam = RulesParamDataWrapper.new({paramName = "kingAllyTeam"})

-- the frame number at which the current king initially became the king
-- used to keep track of the durration of the current king's reign
local kingStartFrame = RulesParamDataWrapper.new({paramName = "kingStartFrame"})

-- allyTeamId to RulesParamDataWrapper of number of frames for which that team has held the hill
-- does not reflect the duration of the current king's reign--these values are only updated when the king changes
local allyTeamKingTime = {}

-- the frame at which the current king will win if he remains king
local kingWinFrame = math.huge

-- the allyTeamId of the ally team currently in the process of capturing the hill
local capturingAllyTeam = RulesParamDataWrapper.new({paramName = "capturingAllyTeam"})

-- the frame at which the current capturing process will be complete (counting up or down, see below)
local capturingCompleteFrame = RulesParamDataWrapper.new({paramName = "capturingCompleteFrame", value = 0})

-- specifies the direction in which capturing progress is being made
-- true = up = progressing toward capturing the hill, false = down = losing progress that was previously made
local capturingCountingUp = RulesParamDataWrapper.new({paramName = "capturingCountingUp", value = false})

-- #endregion

-- Parses the modoptions that define the hill area and returns a MapArea object
local function parseAreaModOptions(left, right, top, bottom, type)
	if type == "rect" then
		-- Map coords have 0 at top left corner
		return RectMapArea.new({left = left*mapSizeX/mapAreaScale, top = top*mapSizeZ/mapAreaScale, right = right*mapSizeX/mapAreaScale, bottom = bottom*mapSizeZ/mapAreaScale})
	elseif type == "circle" then
		--Make sure that the area defined by left, right, top, bottom is square for a circle
		--Mod option coords are always [0,200] but map is not always square
		--Same code as used in lobby 'gui_battle_room_window.lua'
		--Invalid mod option coords must produce same circle as is rendered in lobby
		local currentAreaWidth = right - left
		local currentAreaHeight = bottom - top
		local currentAreaAspectRatio = currentAreaWidth / currentAreaHeight
		local targetAspectRatio =  mapSizeZ / mapSizeX
		if targetAspectRatio >= currentAreaAspectRatio then--needs to be made more wide and less tall, so keep width same and reduce height
			local newHeight = currentAreaWidth / targetAspectRatio
			bottom = top + newHeight
		else--needs to be made more tall and less wide, so keep height the same and reduce width
			local newWidth = currentAreaHeight * targetAspectRatio
			right = left + newWidth
		end
		
		return CircleMapArea.new({x = ((left + right)/2)*mapSizeX/mapAreaScale, z = ((top + bottom)/2)*mapSizeZ/mapAreaScale, radius = ((right - left)/2)*mapSizeX/mapAreaScale})
	end
end

-- Sets the current king's global LOS to the value only if the mod option is enabled
local function setKingGlobalLOS(value)
	if kingGlobalLos and kingAllyTeam.value then
		Spring.SetGlobalLos(kingAllyTeam.value, value)
	end
end

-- Destroys all hill buildings only if the mod option is enabled
local function destroyHillBuildings()
	if not explodehillunits then
		return
	end
	for building in hillBuildings:iter() do
		Spring.DestroyUnit(building)
	end
	hillBuildings:clear()
end

-- Removes the current king if any and resets the capturing timer to zero
local function resetKingAndCapturing()
	setKingGlobalLOS(false)
	kingAllyTeam:setAndSend(nil)
	capturingAllyTeam:setAndSend(nil)
	capturingCompleteFrame:setAndSend(0)
	capturingCountingUp:setAndSend(false)
	kingWinFrame = math.huge
	destroyHillBuildings()
end

--Disqualifies the specified ally team (sets the king time to negative to indicate disqualified)
local function disqualifyAllyTeam(allyTeamId)
	local kingTime = allyTeamKingTime[allyTeamId]
	if kingAllyTeam.value == allyTeamId then
		--Add current time to king time before removing king
		local currentDayFrames, days = Spring.GetGameFrame()
		local frame = currentDayFrames + (days * dayFrames)
		kingTime:set(kingTime.value + frame - kingStartFrame.value)
		resetKingAndCapturing()
	end
	kingTime:setAndSend(math.min(-kingTime.value, -1e-16)) --negative value indicates disqualified, set to very small negative value if it is zero because negative zero doesn't work
end

--Called when the addon is (re)loaded.
function gadget:Initialize()
	if not gadgetHandler:IsSyncedCode() then
		gadgetHandler.RemoveGadget()
		return
	end
	
	--Get mod options to see if KOTH is enabled and, if so, get related settings
	local modOptions = Spring.GetModOptions()
	
	--Disable this gadget if KOTH game mode is not enabled
	if not modOptions.kingofthehillenabled then
		gadgetHandler.RemoveGadget()
		return
	end
	
	--Get and parse KOTH related mod options
	hillArea = parseAreaModOptions(modOptions.kingofthehillarealeft, modOptions.kingofthehillarearight,
								modOptions.kingofthehillareatop, modOptions.kingofthehillareabottom,
								modOptions.kingofthehillareatype)
	buildOutsideBoxes = not modOptions.kingofthehillbuildoutsideboxes
	winKingTime = (tonumber(modOptions.kingofthehillwinkingtime) or 10) * 60 * 1000
	winKingTimeFrames = fps * winKingTime / 1000
	captureDelay = (tonumber(modOptions.kingofthehillcapturedelay) or 20) * 1000
	captureDelayFrames = fps * captureDelay / 1000
	healthMultiplier = tonumber(modOptions.kingofthehillhealthmultiplier) or 1
	kingGlobalLos = modOptions.kingofthehillkinggloballos
	noDamageInBoxes = modOptions.kingofthehillnodamageinboxes
	explodehillunits = modOptions.kingofthehillexplodehillunits
	
	--If the widget was reloaded, buildings in the hill area have to be registered
	for _, unitId in ipairs(hillArea:getUnitsInside()) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitId)]
		if unitDef.isBuilding or unitDef.isStaticBuilder then
			hillBuildings:add(unitId)
		end
	end
	
	local gaiaAllyTeamID
	if Spring.GetGaiaTeamID() then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
	end
	
	--Populate the startBoxes table with all allyTeam start boxes in the form of RectMapAreas
	--and populate teamAllyTeams, allyTeamLives, and allyTeamKingTime tables
	--Also, in case the gadget is being reloaded, disqualify any dead teams, register any
	--existing capture qualified units, and register any units in the hill
	for _, allyTeamId in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamId ~= gaiaAllyTeamID then
			local xMin, zMin, xMax, zMax = Spring.GetAllyTeamStartBox(allyTeamId)
			startBoxes[allyTeamId] = RectMapArea.new{left = xMin, top = zMin, right = xMax, bottom = xMax}
			local numAliveTeams = 0
			for _, teamId in ipairs(Spring.GetTeamList(allyTeamId)) do
				teamToAllyTeam[teamId] = allyTeamId
				local isDead = select(3, Spring.GetTeamInfo(teamId))
				if not isDead then
					numAliveTeams = numAliveTeams + 1
				end
				--Register all capture qualified units from this team
				for _, unitId in ipairs(Spring.GetTeamUnitsByDefs(teamId, {captureQualifiedUnitDefIds:unpack()})) do
					captureQualifiedUnits[unitId] = allyTeamId
				end
			end
			allyTeamLives[allyTeamId] = numAliveTeams
			allyTeamKingTime[allyTeamId] = RulesParamDataWrapper.new({paramName = "allyTeamKingTime" .. allyTeamId, value = 0})
			if numAliveTeams <= 0 then
				disqualifyAllyTeam(allyTeamId)
			end
		end
	end
	
	--Remove the call-in that cancels unpermitted build commands if building outside boxes is allowed
	if buildOutsideBoxes then
		gadgetHandler.RemoveCallIn(nil, "AllowCommand")
	end
	--Remove the call-in that cancels damage inside a unit's own start area if that mod option is disabled
	if not noDamageInBoxes then
		gadgetHandler.RemoveCallIn(nil, "UnitPreDamaged")
	end
end

--Called when the addon or the game is shutdown.
function gadget:Shutdown()
	
end

--Called upon the start of the game.
function gadget:GameStart()
	
end

-- A function that updates capturingCompleteFrame when capturingCountingUp is reversed
local function setCapturingCountingUp(value, currentFrame)
	if(value == capturingCountingUp.value) then
		return
	end
	capturingCountingUp:setAndSend(value)
	
	local remainingFrames = math.max(capturingCompleteFrame.value - currentFrame, 0)
	capturingCompleteFrame:setAndSend(currentFrame + captureDelayFrames - remainingFrames)
end

local updateCounter = framesPerUpdate
--Called for every game simulation frame
--Used to check if capture qualified units are in hill, conduct king changes, and check if the game is over
--In general, performs updates to main KOTH states based on current game conditions
function gadget:GameFrame(frame)
	updateCounter = updateCounter - 1
	if updateCounter > 0 then
		return
	end
	updateCounter = framesPerUpdate
	
	-- Get all ally teams that are in the hill to determine if it is being captured
	local allyTeamsInHill = Set.new()
	for unitId, allyTeamId in pairs(captureQualifiedUnits) do
		local unitX, _, unitZ = Spring.GetUnitPosition(unitId)
		if hillArea:isPointInside(unitX, unitZ) then
			allyTeamsInHill:add(allyTeamId)
		end
	end
	
	-- Logic to determine if hill is being captured
	if kingAllyTeam.value then
		if allyTeamsInHill:contains(kingAllyTeam.value) then
			setCapturingCountingUp(true, frame)
		else
			setCapturingCountingUp(false, frame)
		end
	else
		if allyTeamsInHill.size == 1 and (frame >= capturingCompleteFrame.value or allyTeamsInHill:unpack() == capturingAllyTeam.value) then
			setCapturingCountingUp(true, frame)
			capturingAllyTeam:setAndSend(allyTeamsInHill:unpack())
		else
			setCapturingCountingUp(false, frame)
		end
	end
	
	-- End the game if the king won
	if frame >= kingWinFrame then
		Spring.GameOver({kingAllyTeam.value})
	end
	
	-- Capture the hill if the captureDelay has elapsed
	if frame >= capturingCompleteFrame.value then
		if kingAllyTeam.value and not capturingCountingUp.value then
			-- Remove the king and add the time of this stint to their total
			local kingTime = allyTeamKingTime[kingAllyTeam.value]
			kingTime:setAndSend(kingTime.value + frame - kingStartFrame.value)
			setKingGlobalLOS(false)
			kingAllyTeam:setAndSend(nil)
			kingStartFrame:setAndSend(frame)
			destroyHillBuildings()
			kingWinFrame = math.huge
		elseif not kingAllyTeam.value and capturingCountingUp.value then
			-- Set the new king and the king starting/win frame
			kingAllyTeam:setAndSend(capturingAllyTeam.value)
			kingStartFrame:setAndSend(frame)
			setKingGlobalLOS(true)
			kingWinFrame = frame + winKingTimeFrames - allyTeamKingTime[kingAllyTeam.value].value
		end
	end
	
end

--Called when a unit is transferred between teams. Used to keep track of all capture-qualified units and their ally teams
--Note: I assume this function is called when enemy units are captured, otherwise it is not needed since you cannot give units outside your allyTeam
function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if not captureQualifiedUnitDefIds:contains(unitDefID) then
		return
	end
	captureQualifiedUnits[unitID] = teamToAllyTeam[newTeam]
end

--Called at the moment the unit is created.
--Used to track buildings inside the hill to be blown up upon transfer of the throne
--Also adjusts capture qualified units' health according to the health multiplier
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if healthMultiplier ~= 1 and captureQualifiedUnitDefIds:contains(unitDefID) then
		local oldHealth, oldMaxHealth = Spring.GetUnitHealth(unitID)
		Spring.SetUnitMaxHealth(unitID, oldMaxHealth * healthMultiplier)
		Spring.SetUnitHealth(unitID, oldHealth * healthMultiplier)
	end
	local unitDef = UnitDefs[unitDefID]
	if unitDef.isBuilding or unitDef.isStaticBuilder then
		local unitX, _, unitZ = Spring.GetUnitPosition(unitID)
		if hillArea:isPointInside(unitX, unitZ) then
			hillBuildings:add(unitID)
		end
	end
end

--Called at the moment the unit is completed [constructed]. Used to start tracking capture-qualified units.
function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if not captureQualifiedUnitDefIds:contains(unitDefID) then
		return
	end
	captureQualifiedUnits[unitID] = teamToAllyTeam[unitTeam]
end

--Called when a unit is destroyed. Used to stop tracking capture-qualified units and buildings in the hill that are destroyed
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	captureQualifiedUnits[unitID] = nil
	hillBuildings:remove(unitID)
end

--Called when a team dies. Used to disqualify allyTeams with no remaining alive teams.
function gadget:TeamDied(teamID)
	local allyTeamId = teamToAllyTeam[teamID]
	local newLives = allyTeamLives[allyTeamId] - 1
	allyTeamLives[allyTeamId] = newLives
	if newLives <= 0 then
		disqualifyAllyTeam(allyTeamId)
	end
end

--Called when the command is given, before the unit's queue is altered. The return value is whether it should be let into the queue.
--The queue remains untouched when a command is blocked, whether it would be queued or replace the queue.
--Used to block build commands that are outside of permitted areas if buildOutsideBoxes is false
function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	local buildingUnitDef = UnitDefs[-cmdID]
	if buildingUnitDef and (buildingUnitDef.isBuilding or buildingUnitDef.isStaticBuilder) then
		local cmdX, _, cmdZ, rotation = table.unpack(cmdParams)
		-- rotation 0=south(-z), 1=east(+x), 2=north(+z), 3=west(-x), unitDef sizeX and sizeZ seem to refer to north/south orientation
		local sizeX = (rotation % 2 == 0 and buildingUnitDef.xsize or buildingUnitDef.zsize) * squareSize
		local sizeZ = (rotation % 2 == 0 and buildingUnitDef.zsize or buildingUnitDef.xsize) * squareSize
		local allyTeamId = teamToAllyTeam[unitTeam]
		local allyTeamStartRect = startBoxes[allyTeamId]
		if allyTeamStartRect:isBuildingInside(cmdX, cmdZ, sizeX, sizeZ) or (kingAllyTeam.value == allyTeamId and hillArea:isBuildingInside(cmdX, cmdZ, sizeX, sizeZ)) then
			return true
		end
		return false
	end
	return true
end

--Called just before unit is created.
--Used to block buildings from being created outside of permitted areas if buildOutsideBoxes is false
--It is possible to queue a build command and then loose the hill, thus we need to block the unit creation in addition to the commands
function gadget:AllowUnitCreation(unitDefId, builderId, builderTeam, x, y, z, facing)
	local buildingUnitDef = UnitDefs[unitDefId]
	if buildingUnitDef and (buildingUnitDef.isBuilding or buildingUnitDef.isStaticBuilder) then
		-- facing 0=south(-z), 1=east(+x), 2=north(+z), 3=west(-x), unitDef sizeX and sizeZ seem to refer to north/south orientation
		local sizeX = (facing % 2 == 0 and buildingUnitDef.xsize or buildingUnitDef.zsize) * squareSize
		local sizeZ = (facing % 2 == 0 and buildingUnitDef.zsize or buildingUnitDef.xsize) * squareSize
		local allyTeamId = teamToAllyTeam[builderTeam]
		local allyTeamStartRect = startBoxes[allyTeamId]
		if allyTeamStartRect:isBuildingInside(x, z, sizeX, sizeZ) or (kingAllyTeam.value == allyTeamId and hillArea:isBuildingInside(x, z, sizeX, sizeZ)) then
			return true
		end
		return false
	end
	return true
end

--Called before damage is applied to the unit, allows fine control over how much damage and impulse is applied.
--Used to prevent damage in start boxes
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if unitTeam ~= attackerTeam then
		local unitX, _, unitZ = Spring.GetUnitPosition(unitID)
		local allyTeamId = teamToAllyTeam[unitTeam]
		if startBoxes[allyTeamId]:isPointInside(unitX, unitZ) then
			return 0, 0
		end
	end
end