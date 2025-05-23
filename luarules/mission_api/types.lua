
-- @start
-- @module Mission API

--============================================================--

--local trackedUnits = GG['MissionAPI'].Tracker.units

--============================================================--

-- Validation

--============================================================--

--- Logs a 'Missing Field' error
-- @string file The name of the file logging the error
-- @string module The name of the module logging the error
-- @string object The name of the object with the missing field
-- @string field The name of the missing field
local function errorMissingField(file, module, object, field)
	Spring.Log(file, LOG.ERROR, string.format("[%s] '%s' is missing field '%s'", module, object, field))
end

----------------------------------------------------------------

--- Logs an 'Unexpected Type' error
-- @string file The name of the file logging the error
-- @string module The name of the module logging the error
-- @string object The name of the object with the invalid field
-- @string field The name of the invalid field
-- @string expected The expected type of the field
-- @string got The actual type of the field
local function errorUnexpectedType(file, module, object, field, expected, got)
	Spring.Log(file, LOG.ERROR, string.format("[%s] Field '%s' in '%s' has an unexpected type. Expected %s, got %s", module, field, object, expected, got))
end

----------------------------------------------------------------

--- Logs an 'Unexpected Array Size' error
-- @string file The name of the file logging the error
-- @string module The name of the module logging the error
-- @string object The name of the object with the invalid field
-- @string field The name of the invalid field
-- @number expected The expected length of the array
-- @number got The actual length of the array
local function errorUnexpectedArraySize(file, module, object, field, expected, got)
	Spring.Log(file, LOG.ERROR, string.format("[%s] Field '%s' in '%s' is array of unexpected size. Expected %i, got %i", module, field, object, expected, got))
end

----------------------------------------------------------------

--- Automates checking field validity and logs appropriate validity errors
-- @string fileName The name of the file used for error logging
-- @string moduleName The name of the module used for error logging
-- @string objectName The name of the object with the field being checked
-- @string fieldName The name of the field being checked
-- @param field The value of the field being checked
-- @string expectedType The expected type of the field being checked
-- @bool required If the field is required to have a value
-- @treturn bool False if any validity error is found
local function checkField(fileName, moduleName, objectName, fieldName, field, expectedType, required)
	fileName = fileName or 'types.lua'
	moduleName = moduleName or 'Mission API'

	local valid = true

	if required and field == nil then
		errorMissingField(fileName, moduleName, objectName, fieldName)
		valid = false
	end

	if field and type(field) ~= expectedType then
		errorUnexpectedType(fileName, moduleName, objectName, fieldName, expectedType, type(field))
		valid = false
	end

	return valid
end

--============================================================--

-- Proximity Monitor

--============================================================--

--- Metatable for Proximity Monitor objects
local proximityMonitor = {
	__name = 'Proximity Monitor', -- Meta name used for type checking

	position = {0, 0}, -- {x, z} position of the proximity monitor
	size = 0, -- Radius or {x, z} size of proximity monitor, for cylindrical and rectangular proximity monitors respectively

	team = Spring.ALL_UNITS, -- TeamID for finding units inside proximity monitor

	onEnter = nil, -- function, called when a unit enters the proximity monitor
	onLeave = nil, -- function, called when a unit leaves the proximity monitor

	units = {}, -- units inside the proximity monitor on last poll
}
proximityMonitor.__index = proximityMonitor

----------------------------------------------------------------

--- Creates a new instance of Proximity Monitor
-- @tab position Array of length 2, {x, z}, for the 2D position of the proximity monitor
-- @tparam number|table Radius or {x, z} size of proximity monitor, for cylindrical and rectangular proximity monitors respectively
-- @number team TeamID used as filter for units inside proximity monitor
-- @func onEnter Function called when a unit enters the proximity monitor. UnitID and UnitDefID are passed as arguments
-- @func onLeave Function called when a unit leaves the proximity monitor. UnitID and UnitDefID are passed as arguments
-- @treturn table Instance derived from the Proximity Monitor metatable
function proximityMonitor:new(position, size, team, onEnter, onLeave)
	local object = {}

	setmetatable(object, self)

	object.position = position or self.position
	object.size = size or self.size

	object.team = team or self.team

	object.onEnter = onEnter or self.onEnter
	object.onLeave = onLeave or self.onLeave

	return object
end

----------------------------------------------------------------

--- Validates the Proximity Monitor's parameters
-- @string file The name of the file to be used for logging validity errors
-- @string module The name of the module to be used for logging validity errors
-- @return boolean False if any validity errors are found
function proximityMonitor:validate(file, module)
	local valid = true

	if not self.position then
		errorMissingField(file, module, self.__name, 'position')
	elseif type(self.position) ~= 'table' then
		errorUnexpectedType(file, module, self.__name, 'position', 'table', type(self.position))
	elseif #self.position ~= 2 then
		Spring.Log(file, LOG.ERROR, string.format("[%s] Field 'position' in 'Proximity Monitor' has unexpected length, expected 2, got %i", module, #self.position))
	end

	if not self.size then
		errorMissingField(file, module, self.__name, 'size')
	elseif type(self.size) ~= 'number' and type(self.size) ~= 'table' then
		errorUnexpectedType(file, module, self.__name, 'size', 'table or number', type(self.size))
	elseif type(self.size) == 'table' and #self.size ~= 2 then
		Spring.Log(file, LOG.ERROR, string.format("[%s] Field 'size' in 'Proximity Monitor' has unexpected length, expected 2, got %i", module, #self.position))
	end

	valid = valid and checkField(file, module, self.__name, 'width', self.width, 'number', true)
	valid = valid and checkField(file, module, self.__name, 'height', self.height, 'number', false)
	valid = valid and checkField(file, module, self.__name, 'team', self.team, 'number', true)
	valid = valid and checkField(file, module, self.__name, 'onEnter', self.onEnter, 'function', false)
	valid = valid and checkField(file, module, self.__name, 'onLeave', self.onLeave, 'function', false)

	return valid
end

----------------------------------------------------------------

--- Gets all units inside the proximity monitor, filtered with the proximity monitor's teamID
-- @treturn table {[1] = UnitID, ...}
function proximityMonitor:getUnits()
	local units = {}

	if not self.height then
		units = Spring.GetUnitsInCylinder(self.x, self.z, self.width, self.team)
	else
		units = Spring.GetUnitsInRectangle(self.x, self.z, self.x + self.width, self.z + self.height, self.team)
	end

	return units
end
----------------------------------------------------------------

--- Polls the proximity monitor, checking if any units have entered or left and updating the current units table
function proximityMonitor:poll()
	local currentUnits = self.getUnits()

	if self.onEnter then
		for _, unitID in ipairs(currentUnits) do
			if not table.contains(self.units, unitID) then
				self.onEnter(unitID)
			end
		end
	end

	if self.onLeave then
		for _, unitID in ipairs(self.units) do
			if not table.contains(currentUnits, unitID) then
				self.onLeave(unitID)
			end
		end
	end

	self.units = currentUnits
end

--============================================================--

-- Timer

--============================================================--

--- Metatable for Timer objects
local timer = {
	__name = 'Timer', -- Meta name used for type checking

	elapsed = 0, -- Current count of frames since started
	length = 0, -- Length of timer in frames (60/s)

	loop = false, -- If the timer should restart after finishing
	running = false, -- If the timer is currently running

	onUpdate = nil, -- Function called every frame with the alpha (0.0 - 1.0) of the timer, for LERPing
	onFinished = nil, -- Function called when the timer finishes
}
timer.__index = timer

----------------------------------------------------------------

--- Creates a new instance of Timer
-- @number length Length of the timer in frames (60/s)
-- @bool loop If the timer should restart after finishing
-- @func onUpdate Function called every frame that the timer is running. Passes the alpha (0.0 - 1.0) of the timer as argument
-- @func onFinished Function called when the timer finishes
-- @treturn table Instance derived from the Timer metatable
function timer:new(length, loop, onUpdate, onFinished)
	local object = {}

	setmetatable(object, self)

	object.elapsed = self.elapsed
	object.length = length or self.length

	object.loop = loop or self.loop
	object.running = self.running

	object.onUpdate = onUpdate or self.onUpdate
	object.onFinished = onFinished or self.onFinished

	return object
end

----------------------------------------------------------------

--- Validates the Timer's parameters
-- @string file The name of the file to be used for logging validity errors
-- @string module The name of the module to be used for logging validity errors
function timer:validate(file, module)
	local valid = true

	valid = valid and checkField(file, module, self.__name, 'length', self.length, 'number', true)
	valid = valid and checkField(file, module, self.__name, 'loop', self.loop, 'bool', false)
	valid = valid and checkField(file, module, self.__name, 'onUpdate', self.onUpdate, 'function', false)
	valid = valid and checkField(file, module, self.__name, 'onFinished', self.onFinished, 'function', false)

	return valid
end

----------------------------------------------------------------

--- Starts the timer. If paused, will continue at the state the timer was paused
function timer:start()
	self.running = true
end

----------------------------------------------------------------

--- Pauses the timer, does not reset the timer's current state
function timer:pause()
	self.running = false
end

----------------------------------------------------------------

--- Stops the timer and resets its current state
function timer:stop()
	self.elapsed = 0
	self.running = false
end

----------------------------------------------------------------

--- Polls the timer, incrementing its elapsed and calling the appropriate functions
function timer:poll()
	if not self.running then return end

	self.elapsed = self.elapsed + 1

	if self.onUpdate then self.onUpdate(self.length / self.elapsed) end

	if self.elapsed == self.length then
		if self.onFinished then self.onFinished() end
		if not self.loop then self.running = false end
		self.elapsed = 0
	end
end

--============================================================--

-- Unit

--============================================================--

--- Metatable for Unit objects
local unit = {
	__name = 'Unit', -- Meta name for type checking

	TYPE = {
		NAME = 0, -- All units tracked with the ID as the tracked name
		ID = 1, -- Only the unit with the ID as UnitID
		DEF_ID = 2, -- All units with the ID as UnitDefID
		DEF_NAME = 3, -- All units wit hthe ID as UnitDefName
	},

	type = 0, -- The type of ID given, must be Unit.TYPE
	ID = 0, -- The name or ID of the given type
	team = Spring.ALL_UNITS, -- The teamID to use for filtering units
}
unit.__index = unit

----------------------------------------------------------------

--- Creates a new instance of Unit
-- @tparam Unit.TYPE type The type of ID given
-- @tparam string|number ID The name or ID of the given type
-- @number team The teamID to use for filtering units
-- @treturn table Instance derived from the Unit metatable
function unit:new(type, ID, team)
	local object = {}
	setmetatable(object, self)

	object.type = type or self.type
	object.ID = ID or self.ID
	object.team = team or self.team

	return object
end

----------------------------------------------------------------

--- Validates the Unit's parameters
-- @string file The name of the file to be used for logging validity errors
-- @string module The name of the module to be used for logging validity errors
-- @treturn boolean False if any validity errors are found
function unit:validate(file, module)
	file = file or 'types.lua'
	module = module or 'Mission API'

	if self.ID == nil then
		errorMissingField(file, module, self.__name, 'ID')
		return false
	end

	if not self.type then
		errorMissingField(file, module, self.__name, 'type')
		return false
	end

	if not self.team then
		errorMissingField(file, module, self.__name, 'team')
		return false
	end

	if self.type == self.TYPE.NAME or self.type == self.TYPE.DEF_NAME then
		if type(self.ID) ~= 'string' then
			Spring.Log(file, LOG.ERROR, string.format("[%s] Unit of type '%i' expects ID of type 'string', got %s instead", module, type(self.ID)))
			return false
		end
	elseif self.type == self.TYPE.ID or self.type == self.TYPE.DEF_ID then
		if type(self.ID) ~= 'string' then
			Spring.Log(file, LOG.ERROR, string.format("[%s] Unit of type %i expects ID of type 'number', got %s instead", module, type(self.ID)))
			return false
		end
	else
		Spring.Log(file, LOG.ERROR, string.format("[%s] Unit has unhandled type '%i'", module, self.type))
		return false
	end

	return true
end

----------------------------------------------------------------

--- Checks if the unit matches the given unitID or unitDefID depending on the Unit's type
-- Unit.TYPE.NAME will check if the unitID exists in the array of tracked units with the given name
-- Unit.TYPE.ID will check if the Unit's ID and the given unitID match
-- Unit.TYPE.DEF_ID or Unit.Type.DEF_NAME will check if the Unit has the given unitDefID
-- @number unitID The unitID of the unit to compare to
-- @number unitDefID the unitDefID of the unit to compare to
-- @treturn boolean True if the Unit matches the unitID or unitDefID
function unit:isUnit(unitID, unitDefID)
	if not self.teamIsTeam(self.team, Spring.GetUnitTeam(unitID)) then return false end

	if self.type == self.TYPES.NAME then
		return table.contains(trackedUnits[self.ID], unitID)
	elseif self.type == self.TYPE.ID then
		return unitID == self.ID
	elseif self.type == self.TYPE.DEF_ID then
		return unitDefID == self.ID
	elseif self.type == self.TYPE.DEF_NAME then
		return UnitDefNames[self.ID] == unitDefID
	end
end

----------------------------------------------------------------

--- Gets all units that match the Unit
-- Unit.TYPE.NAME will return all tracked units with the given name
-- Unit.TYPE.ID will just return the ID. Does not check if the ID is valid
-- Unit.TYPE.DEF_ID or Unit.TYPE.DEF_NAME returns all existing units of the given type and with the given teamID
-- @treturn table {[1] = unitID, ...}
function unit:getUnits()
	if self.type == self.TYPE.NAME then
		return trackedUnits[self.ID]
	elseif self.type == self.TYPE.ID then
		return {self.ID}
	elseif self.type == self.TYPE.DEF_ID then
		return Spring.GetTeamUnitsByDefs(self.team, self.ID)
	elseif self.type == self.TYPE.DEF_NAME then
		return Spring.GetTeamUnitsByDefs(self.team, UnitDefNames[self.ID])
	end
end

----------------------------------------------------------------

--- Checks if the Unit exists
-- @treturn boolean True if unit exists. For types other than Unit.TYPE.ID, will return true if any matching units exist
function unit:exists()
	local units = self.getUnits()

	for _, unitID in ipairs(units) do
		if Spring.ValidUnitID(unitID) then
			return true
		end
	end

	return false
end

----------------------------------------------------------------

function unit:teamIsTeam(teamA, teamB)
	if teamA == teamB then return true end

	if teamA == Spring.ALL_UNITS or teamB == Spring.ALL_UNITS then
		return true
	end

	if teamA == Spring.MY_UNITS then
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			local _, _, _, teamID, _ = Spring.GetPlayerInfo(playerID)
			if teamB == teamID then return true end
		end
	end

	if teamB == Spring.MY_UNITS then
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			local _, _, _, teamID, _ = Spring.GetPlayerInfo(playerID)
			if teamA == teamID then return true end
		end

		return false
	end

	if teamA == Spring.ALLY_UNITS then
		return Spring.AreTeamsAllied(Spring.GetLocalTeamID(), teamB)
	end

	if teamB == Spring.ALLY_UNITS then
		return Spring.AreTeamsAllied(Spring.GetLocalTeamID(), teamA)
	end

	if teamA == Spring.ENEMY_UNITS then
		return not Spring.AreTeamsAllied(Spring.GetLocalTeamID(), teamB)
	end

	if teamB == Spring.ENEMY_UNITS then
		return not Spring.AreTeamsAllied(Spring.GetLocalTeamID(), teamA)
	end

	return false
end

--============================================================--

-- UnitDef

--============================================================--

--- Metatable for UnitDef objects
local unitDef = {
	__name = 'UnitDef', -- Meta name for type checking

	TYPE = {
		NAME = 0, -- ID is UnitDefName
		ID = 1 -- ID is UnitDefID
	},

	type = 0, -- The type of ID given, must be UnitDef.TYPE
	ID = 0, -- The name or ID of the given type
	team = Spring.ALL_UNITS, -- The teamID used for filtering units
}
unitDef.__index = unitDef

----------------------------------------------------------------

--- Creates a new instance of UnitDef
-- @tparam UnitDef.TYPE type The type of the ID given, must be UnitDef.TYPE
-- @tparam string|number ID The name or ID of the given type
-- @number team The teamID used for filtering units
-- @treturn table Instance derived from the UnitDef metatable
function unitDef:new(type, ID, team)
	local object = {}
	setmetatable(object, self)

	object.type = type or self.type
	object.ID = ID or self.ID
	object.team = team or self.team

	return object
end

----------------------------------------------------------------

--- Validates the UnitDef's parameters
-- @string file The name of the file to be used for logging validity errors
-- @string module The name of the module to be used for logging validity errors
-- @treturn boolean False if any validity errors are found
function unitDef:validate(file, module)
	file = file or 'types.lua'
	module = module or 'Mission API'

	if self.ID == nil then
		errorMissingField(file, module, self.__name, 'ID')
		return false
	end

	if self.type == self.TYPE.NAME then
		if type(self.ID) ~= 'string' then
			Spring.Log(file, Log.ERROR, string.format("[%s] UnitDef of type %i expects ID of type 'string', got %s instead", module, self.type, type(self.ID)))
			return false
		end
	elseif self.type == self.TYPE.ID then
		if type(self.ID) ~= 'number' then
			Spring.Log(file, Log.ERROR, string.format("[%s] UnitDef of type %i expects ID of type 'number', got %s instead", module, self.type, type(self.ID)))
			return false
		end
	else
		Spring.Log(file, LOG.ERROR, string.format("[%s] UnitDef has unhandled type '%i'", module, self.type))
		return false
	end

	return true
end

----------------------------------------------------------------

--- Convenience function for getting the UnitDefID
-- @treturn number The ID converted to a UnitDefID
function unitDef:getID()
	if self.type == self.TYPE.ID then
		return self.ID
	elseif self.type == self.TYPE.NAME then
		return UnitDefNames[self.ID]
	end
end

----------------------------------------------------------------

--- Convenience function for getting the UnitDefName
-- @treturn string The ID converted to a UnitDefName
function unitDef:getName()
	if self.type == self.TYPE.NAME then
		return self.ID
	elseif self.type == self.TYPE.ID then
		return UnitDefs[self.ID].name
	end
end

----------------------------------------------------------------

--- Gets all units that match the UnitDef
-- @treturn table {[1] = unitID, ...}
function unitDef:getUnits()
	return Spring.GetTeamUnitsByDefs(self.team, self.getID())
end

----------------------------------------------------------------

--- Checks if any unit exists matching the UnitDef
-- @treturn boolean True if any matching unit exists
function unitDef:exists()
	return #(self.getUnits()) > 0
end

--============================================================--

-- Vec2

--============================================================--

--- Metatable for Vec2 objects
local vec2 = {
	__name = 'Vec2',

	x = 0,
	z = 0,
}
vec2.__index = vec2

----------------------------------------------------------------

--- Creates a new instance of Vec2
-- @number x The X value
-- @number z The Z value
-- @treturn table Instance derived from Vec2 metatable
function vec2.new(x, z)
	local object = setmetatable({}, vec2)

	if type(x) == 'table' then
		z = x.z
		x = x.x
	end

	object.x = x or object.x
	object.z = z or object.z

	return object
end

----------------------------------------------------------------

--- Validates the Vec2's parameters
-- @string file The name of the file to be used for logging validity errors
-- @string module The name of the module to be used for logging validity errors
-- @treturn boolean False if any validity errors are found
function vec2:validate(file, module)
	local valid = true

	valid = valid and checkField(file, module, self.__name, 'x', self.x, 'number', true)
	valid = valid and checkField(file, module, self.__name, 'z', self.z, 'number', true)

	return valid
end

--============================================================--

-- Vec3

--============================================================--

--- Metatable for Vec3 objects
local vec3 = {
	__name = 'Vec3', -- Meta name used for type checking

	x = 0, -- X value
	y = 0, -- Y value (height)
	z = 0, -- Z value
}
vec3.__index = vec3

----------------------------------------------------------------

--- Creates a new instance of Vec3
-- @number x The X value
-- @number y The Y value (height)
-- @number z The Z value
-- @treturn table Instance derived from the Vec3 metatable
function vec3:new(x, y, z)
	local object = {}

	setmetatable(object, self)

	object.x = x or self.x
	object.y = y or self.y
	object.z = z or self.z

	return object
end

----------------------------------------------------------------

--- Validates the Vec3's parameters
-- @string file The name of the file to be used for logging validity errors
-- @string module The name of the module to be used for logging validity errors
-- @treturn boolean False if any validity errors are found
function vec3:validate(file, module)
	local valid = true

	valid = valid and checkField(file, module, self.__name, 'x', self.x, 'number', true)
	valid = valid and checkField(file, module, self.__name, 'y', self.y, 'number', true)
	valid = valid and checkField(file, module, self.__name, 'z', self.z, 'number', true)

	return valid
end
--============================================================--
-- Direction
--============================================================--
local direction = {
	__name = 'Direction', -- Meta name for type checking
	value = 0,

	enumValues = {
		[0] = 'south',
		south = 0,
		s = 0,
		[1] = 'east',
		east = 1,
		e = 1,
		[2] = 'north',
		north = 2,
		n = 2,
		[3] = 'west',
		west = 3,
		w = 3,
	}
}
direction.__index = direction

function direction.new(value)
	local object = setmetatable({}, direction)

	if type(value) == 'string' then
		value = object.enumValues[value:lower()] or value
	end

	object.value = value or object.value

	return object
end

function direction:validate(file, module)
	if type(self.value) == 'number' and self.enumValues[self.value] ~= nil then
		return true
	else
		return false
	end
end
----------------------------------------------------------------
--============================================================--

return {
	ProximityMonitor = proximityMonitor,
	Timer = timer,
	Unit = unit,
	UnitDef = unitDef,
	Vec2 = vec2,
	Vec3 = vec3,
	Direction = direction,
}
--@end