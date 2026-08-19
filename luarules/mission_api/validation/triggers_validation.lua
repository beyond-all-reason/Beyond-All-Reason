---
--- Trigger validation: actions, settings and parameters.
---

local SECTION = VFS.Include('luarules/mission_api/validation/validation_report.lua').Sections.Triggers
local validateTableType = VFS.Include('luarules/mission_api/validation/parameter_validators/validator_utils.lua').ValidateTableType
local LABEL = 'Trigger'

--- The shared trigger settings (global, not per trigger type), by the parameter type each
--- is validated as. Their defaults are applied by ProcessRawTriggers in triggers_loader.lua.
local function getSettingTypes(Types)
	return {
		prerequisites = Types.TriggerIDs,
		repeating     = Types.Boolean,
		maxRepeats    = Types.Quantity,
		difficulties  = Types.Table,
		coop          = Types.Boolean,
		active        = Types.Boolean,
		stages        = Types.StageIDs,
	}
end

local function validateTriggerActions(context, report, trigger, triggerID)
	if trigger.actions ~= nil and type(trigger.actions) ~= 'table' then
		report.Error(SECTION, LABEL, triggerID, "Trigger 'actions' field must be a table, got " .. type(trigger.actions))
		return
	end

	if table.isNilOrEmpty(trigger.actions) then
		report.Error(SECTION, LABEL, triggerID, "Trigger has no actions")
		return
	end

	for _, actionID in pairs(trigger.actions) do
		if actionID == '' then
			report.Error(SECTION, LABEL, triggerID, "Trigger has empty action ID")
		elseif not context.Actions[actionID] then
			report.Error(SECTION, LABEL, triggerID, "Trigger has invalid action ID", "Action: " .. tostring(actionID))
		end
	end
end

--- Settings are optional in raw missions; triggers_loader.lua applies the defaults later.
local function validateTriggerSettings(report, parameterValidators, settingTypes, trigger, triggerID)
	local settings = trigger.settings
	if settings == nil then
		return
	end

	local settingsTypeResult = validateTableType(settings)
	if settingsTypeResult then
		report.Error(SECTION, LABEL, triggerID, settingsTypeResult[1].message, "Setting: settings")
		return
	end

	-- Validate the type of each setting. The TriggerIDs and StageIDs types also check
	-- that every listed prerequisite trigger and stage exists.
	for setting, settingType in pairs(settingTypes) do
		if settings[setting] ~= nil then
			for _, result in ipairs(parameterValidators[settingType](settings[setting]) or {}) do
				report.Error(SECTION, LABEL, triggerID, result.message,
					"Setting: " .. setting .. (result.parameterNameSuffix or ''))
			end
		end
	end

	if settings.maxRepeats and not settings.repeating then
		report.Error(SECTION, LABEL, triggerID, "Trigger has maxRepeats setting but is not set to repeating")
	end
end

local function validate(context, report, parameterValidators, validateSchema)
	local settingTypes = getSettingTypes(context.Types)

	for triggerID, trigger in pairs(context.Triggers) do
		if type(trigger) ~= 'table' then
			report.Error(SECTION, LABEL, triggerID, "Trigger data must be a table, got " .. type(trigger))
		else
			validateTriggerActions(context, report, trigger, triggerID)
			validateTriggerSettings(report, parameterValidators, settingTypes, trigger, triggerID)
			validateSchema({ section = SECTION, label = LABEL, id = triggerID },
				context.TriggerParameters, trigger.type, trigger.parameters)
		end
	end
end

return {
	Validate = validate,
}
