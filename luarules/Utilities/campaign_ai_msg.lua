-- Campaign AI messaging system.
-- Message format:
-- "<version>|<cmd1>:<val1>;<val2>;<val3>|<cmd2>:<param1>=<val1.1>,<val1.2>,<val1.3>;<param2>=<val2>;<param3>=<val3>;"

local version = "1"

local delimiter = {
	SEP_PACKET    = "|",
	SEP_COMMAND   = ":",
	SEP_PARAM     = ";",
	SEP_KEY_VALUE = "=",
	SEP_SUBPARAM  = ",",
}

local topic = {
	SET_AI_ACTIVE                    =   1,  -- boolean
	ENABLE_UNITDEFS                  =   2,  -- array of unitDefIDs
	DISABLE_UNITDEFS                 =   3,  -- array of unitDefIDs
	ENABLE_UNITS_CONTROL             =   4,  -- array of unitIDs
	DISABLE_UNITS_CONTROL            =   5,  -- array of unitIDs

	UNIT_WEIGHTS                     =   9,

	UNITDEF_RETREAT                  =  11,

	REGION_AVOID                     =  12,

	FACTORY_ENABLE                   =  13,

	EXEC_ORDER_66                    =  15,
	SET_SCRIPTED_RECRUIT             =  16,  -- boolean

	-- Base starts at 100
	BASE_CREATE                      = 101,
	BASE_REBUILD                     = 102,

	-- Squad Request starts at 200
	REQUEST_SQUAD                    = 201,
	REQUEST_COMPOSE                  = 202,
	REQUEST_CANCEL                   = 203,
	REQUEST_PARAMS                   = 204,
	-- Squad starts at 210
	SQUAD_ASSEMBLE                   = 211,
	SQUAD_DISBAND                    = 212,
	SQUAD_TASK                       = 213,
	SQUAD_PARAMS                     = 214,
}

local param = {
	SQUAD_POS_X        = 1,
	SQUAD_POS_Z        = 2,
	SQUAD_GATHER_RANGE = 3,
	SQUAD_ATTACK_RANGE = 4,
	SQUAD_IS_REPEAT    = 5,
	SQUAD_RETREAT      = 6,
	SQUAD_PRIO_TARGET  = 7,

	BASE_POS_X = 101,
	BASE_POS_Z = 102,
}

local task = {
	TASK_DEFEND  = 1,
	TASK_SCOUT   = 2,
	TASK_RAID    = 3,
	TASK_ATTACK  = 4,
	TASK_BOMB    = 5,
	TASK_ARTY    = 6,
	TASK_AA      = 7,
	TASK_SUPPORT = 8,
	TASK_RETREAT = 9,
}

local function BuildValue(cmd, param)
	return version .. delimiter.SEP_PACKET .. cmd .. delimiter.SEP_COMMAND .. param
end

local function BuildArray(cmd, params)
	local msg = version .. delimiter.SEP_PACKET .. cmd .. delimiter.SEP_COMMAND
	for index, value in ipairs(params) do
		msg = msg .. value .. delimiter.SEP_PARAM
	end
	return msg
end

local function BuildDict(cmd, params)
	local msg = version .. delimiter.SEP_PACKET .. cmd .. delimiter.SEP_COMMAND
	for key, value in pairs(params) do
		msg = msg .. key .. delimiter.SEP_KEY_VALUE .. value .. delimiter.SEP_PARAM
	end
	return msg
end

return {
	version    = version,
	delimiter  = delimiter,
	topic      = topic,
	param      = param,
	task       = task,
	BuildValue = BuildValue,
	BuildArray = BuildArray,
	BuildDict  = BuildDict,
}
