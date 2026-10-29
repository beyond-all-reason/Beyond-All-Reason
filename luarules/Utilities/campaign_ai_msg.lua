-- Campaign AI messaging system.
-- boolean is forbidden; accepted values: 1 as true, 0 as false.
-- Message format:
-- "<version>|<cmd1>:<val1>;<val2>;<val3>|<cmd2>:<param1>=<val1>;<param2>=<val2>;<param3>=<val3.1>,<val3.2>,<val3.3>"

local version = "1"

local delimiter = {
	SEP_PACKET = "|",
	SEP_COMMAND = ":",
	SEP_PARAM = ";",
	SEP_KEY_VALUE = "=",
	SEP_SUBPARAM = ",",
}

local topic = { -- Message topic
	SET_AI_ACTIVE = 1, -- boolean
	ENABLE_UNITDEFS = 2, -- array of unitDefIDs
	DISABLE_UNITDEFS = 3, -- array of unitDefIDs
	ENABLE_UNITS_CONTROL = 4, -- array of unitIDs
	DISABLE_UNITS_CONTROL = 5, -- array of unitIDs
	SET_AI_STATE = 6, -- passive, defensive, aggressive

	SET_UNITDEF_RETREAT_HP = 11,
	SET_FACTORY_ACTIVE = 12,
	SET_MEX_CAP = 13,
	SET_ENGINE_EVENTS_ACTIVE = 14,
	AI_UPDATE_LOOP_PARAMS = 15,
	AI_CONSTRUCTION_PARAMS = 16, -- construct params
	AI_MILITARY_PARAMS = 17,

	-- Base starts at 100
	BASE_PLAN_ID = 101,
	BASE_ADD_BUILDTASK = 102,
	BASE_DEL_BUILDTASK = 103,
	BASE_PLAN_CANCEL = 104,
	BASE_PARAMS = 105,

	-- Squad Request starts at 200
	SQUAD_REQUEST_ID = 201,
	SQUAD_REQUEST_COMPOSE = 202,
	SQUAD_REQUEST_CANCEL = 203,
	SQUAD_REQUEST_PARAMS = 204,
	-- Squad starts at 210
	SQUAD_ID = 211,
	SQUAD_DISBAND = 212,
	SQUAD_TASK = 213,
	SQUAD_PARAMS = 214,
	SQUAD_PATH_PARAMS = 215,
	SQUAD_ESCORT = 216,

	-- Region starts at 300
	BUILD_REGION_ID = 301,
	BUILD_REGION_CLEAR = 302,
	RESERVED_REGION_ID = 303,
	RESERVED_REGION_CLEAR = 304,
	ALLOWED_REGION_ID = 305,
	ALLOWED_REGION_CLEAR = 306,
	ALLOWED_GRID_FILL = 307,
	TRIGGER_REGION_ID = 321,
	TRIGGER_REGION_CLEAR = 322,
}

local signal = { -- Trigger signal
	PREFIX = "ai_", -- signal message prefix
	SQUAD_FINISHED = 201,
	SQUAD_DESTROYED = 202,
	REGION_ENTER = 301,
	REGION_EXIT = 302,
}

local aiState = {
	PASSIVE = 1,
	DEFENSIVE = 2,
	NORMAL = 3,
	AGGRESSIVE = 4,
}

local updateLoop = {
	MILITARY_UPDATE_IDLE = 1,
	MILITARY_UPDATE = 2,
	MILITARY_WATCHDOG = 3,
	MILITARY_DEFENCE_TASKS = 4,
	MILITARY_TRIGGERS_STEP = 5,
	BUILDER_UPDATE_IDLE = 6,
	BUILDER_UPDATE = 7,
	BUILDER_WATCHDOG = 8,
	FACTORY_UPDATE_IDLE = 9,
	FACTORY_UPDATE = 10,
	FACTORY_WATCHDOG = 11,
	SCRIPT_UPDATE = 12,
	UNIT_ACTIONS = 13,
}

local construct = { -- Default AI logic options
	RECRUIT = 1,
	BUILD_TASK = 2,
	FACTORY = 3,
	STORAGE = 4,
	METAL = 5,
	ENERGY = 6,
	ECONOMY = 7,
	DEFENCE = 8,
}

local base = {
	-- Base building anchors
	POSITION = 1,
	METAL_POS = 2,
	ENERGY_CHEAP_POS = 3,
	ENERGY_MODERATE_POS = 4,
	ENERGY_EXPENSIVE_POS = 5,

	-- Base maintenance parameters
	RECLAIM_CONVERT = 11, -- efficiency ratio threshold
	RECLAIM_ENERGY = 12, -- efficiency ratio threshold
}

local plan = { -- Build plan params
	UNITDEF = 1,
	POSITION = 2,
	REBUILD = 3,
}

local military = {
	SCOUTS_COUNT = 1,
	ATTACK_POWER = 2,
	RAID_POWER = 3,
}

local squad = { -- Squad params
	POSITION = 1,
	GATHER_RANGE = 2,
	ATTACK_RANGE = 3,
	REBUILD = 4,
	RETREAT = 5,
	PRIO_TARGET = 6,
}

local task = { -- Task types
	DEFEND = 1,
	SCOUT = 2,
	RAID = 3,
	ATTACK = 4,
	BOMBER = 5,
	ARTILLERY = 6,
	ANTI_AIR = 7,
	SUPPORT = 8,
}

local pathing = { -- Pathing params
	GOAL_RANGE = 1,
	IGNORE_THREAT = 2,
	AVOID_THREAT = 3,
	USE_END_POS = 4,
}

local region = {
	UNITDEF_ID = 1,
	STRUCT_MASK = 2,
}

local structMask = { -- Must match the AI SBlockingMap::StructMask definitions
	NONE = 0,
	ALL = 0xFFFF,
}

local MsgBuilder = {}

function MsgBuilder.new()
	local self = setmetatable({}, MsgBuilder)
	self.buffer = { version }
	return self
end

function MsgBuilder:append(value)
	table.insert(self.buffer, value)
	return self
end

function MsgBuilder:cmdValue(cmd, param)
	self:append(cmd .. delimiter.SEP_COMMAND .. param)
	return self
end

function MsgBuilder:cmdArray(cmd, params)
	self:append(cmd .. delimiter.SEP_COMMAND .. table.concat(params, delimiter.SEP_PARAM))
	return self
end

function MsgBuilder:cmdDict(cmd, params)
	local arrayKV = {}
	for key, value in pairs(params) do
		table.insert(arrayKV, key .. delimiter.SEP_KEY_VALUE .. value)
	end
	self:append(cmd .. delimiter.SEP_COMMAND .. table.concat(arrayKV, delimiter.SEP_PARAM))
	return self
end

function MsgBuilder:cmdDictArray(cmd, key, values)
	self:append(
		cmd .. delimiter.SEP_COMMAND .. key .. delimiter.SEP_KEY_VALUE .. table.concat(values, delimiter.SEP_SUBPARAM)
	)
	return self
end

function MsgBuilder:addValue(value)
	self.buffer[#self.buffer] = self.buffer[#self.buffer] .. delimiter.SEP_PARAM .. value
	return self
end

function MsgBuilder:paramValue(param, value)
	self.buffer[#self.buffer] = self.buffer[#self.buffer]
		.. delimiter.SEP_PARAM
		.. param
		.. delimiter.SEP_KEY_VALUE
		.. value
	return self
end

function MsgBuilder:paramArray(param, values)
	self.buffer[#self.buffer] = self.buffer[#self.buffer]
		.. delimiter.SEP_PARAM
		.. param
		.. delimiter.SEP_KEY_VALUE
		.. table.concat(values, delimiter.SEP_SUBPARAM)
	return self
end

function MsgBuilder:toString()
	return table.concat(self.buffer, delimiter.SEP_PACKET)
end

MsgBuilder.__index = MsgBuilder
MsgBuilder.__tostring = MsgBuilder.toString

return {
	Topic = topic,
	Signal = signal,
	AiState = aiState,
	UpdateLoop = updateLoop,
	Construct = construct,
	Base = base,
	Plan = plan,
	Military = military,
	Squad = squad,
	Task = task,
	Path = pathing,
	Region = region,
	StructMask = structMask,
	MsgBuilder = MsgBuilder,
}
