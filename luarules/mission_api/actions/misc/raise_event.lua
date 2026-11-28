local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function raiseEvent(triggerID)
	GG["MissionAPI"].ActivateTrigger(GG["MissionAPI"].Triggers[triggerID])
end

return {
	{
		type = "RaiseEvent",
		parameters = {
			{ name = "triggerID", required = true, type = ParameterTypes.TriggerID },
		},
		actionFunction = raiseEvent,
	},
}
