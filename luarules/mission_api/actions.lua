local actionTypes = {
	EnableTrigger = 1,
	DisableTrigger = 2,
	IssueOrders = 3,
	AllowCommands = 4,
	RestrictCommands = 5,
	AlterBuildlist = 6,
	EnableBuildOption = 7,
	DisableBuildOption = 8,
	SpawnUnits = 9,
	SpawnConstruction = 10,
	DespawnUnits = 11,
	SpawnWeapons = 12,
	SpawnEffects = 13,
	RevealLOS = 14,
	UnrevealLOS = 15,
	AlterMapZones = 16,
	TransferUnits = 17,
	ControlCamera = 18,
	Pause = 19,
	Unpause = 20,
	PlayMedia = 21,
	SendMessage = 22,
	Victory = 23,
	Defeat = 24,
}

local parameters = {
	[actionTypes.EnableTrigger] = {
		triggerId = {
			required = true,
			type = 'string',
		},
	 },
	[actionTypes.DisableTrigger] = {  },
	[actionTypes.IssueOrders] = {  },
	[actionTypes.AllowCommands] = {  },
	[actionTypes.RestrictCommands] = {  },
	[actionTypes.AlterBuildlist] = {  },
	[actionTypes.EnableBuildOption] = {  },
	[actionTypes.DisableBuildOption] = {  },
	[actionTypes.SpawnUnits] = {  },
	[actionTypes.SpawnConstruction] = {  },
	[actionTypes.DespawnUnits] = {  },
	[actionTypes.SpawnWeapons] = {  },
	[actionTypes.SpawnEffects] = {  },
	[actionTypes.RevealLOS] = {  },
	[actionTypes.UnrevealLOS] = {  },
	[actionTypes.AlterMapZones] = {  },
	[actionTypes.TransferUnits] = {  },
	[actionTypes.ControlCamera] = {  },
	[actionTypes.Pause] = {  },
	[actionTypes.Unpause] = {  },
	[actionTypes.PlayMedia] = {  },
	[actionTypes.SendMessage] = {
		message = {
			required = true,
			type = 'string',
		}
	},
	[actionTypes.Victory] = {  },
	[actionTypes.Defeat] = {  },
}

--[[
	actionId = {
		type = actionTypes.EnableTrigger,
		parameters = {
			triggerId = 'triggerId'
		}
	}
]]

local actions = {}

local function prevalidateActions()
	for actionId, action in pairs(actions) do
		if not action.type then
			Spring.Log('actions.lua', LOG.ERROR, "[Mission API] Action missing type: " .. actionId)
		end

		for parameterName, parameterOptions in pairs(parameters[action.type]) do
			local value = action.parameters[parameterName]
			local type = type(value)

			if value == nil and parameterOptions.required then
				Spring.Log('actopms.lua', LOG.ERROR, "[Mission API] Action missing required parameter. Action: " .. actionId .. ", Parameter: " .. parameterName)
			end

			if value ~= nil and type ~= parameterOptions.type then
				Spring.Log('actopms.lua', LOG.ERROR, "[Mission API] Unexpected parameter type, expected " .. parameterOptions.type .. ", got " .. type .. ". Action: " .. actionId .. ", Parameter: " .. parameterName)
			end
		end
	end
end

local function preprocessRawActions(rawActions)
	for actionId, rawAction in pairs(rawActions) do	
		actions[actionId] = table.copy(rawAction)
	end

	prevalidateActions()
end

local function getActions()
	return actions
end

return {
	Types = actionTypes,
	GetActions = getActions,
	PreprocessRawActions = preprocessRawActions,
}