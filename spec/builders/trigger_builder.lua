-- Trigger Builder
-- Builds a loaded trigger: the table api_missions_triggers.lua holds in
-- GG['MissionAPI'].Triggers and hands to a trigger's call-in handlers.
--
-- A mission author writes only `parameters` and `settings`; conditions_loader's
-- ProcessRawTriggers then fills in the settings defaults and the run-time
-- bookkeeping fields. Build() runs the raw table through it, so a spec fixture
-- carries the same fields a handler meets in game rather than the sparser table a
-- mission file declares.

local conditionsLoader = VFS.Include("luarules/mission_api/conditions_loader.lua")

---@class TriggerMock
---@field parameters table
---@field settings table
---@field triggered boolean
---@field repeatCount number
---@field occurrences number
---@field metricSatisfied boolean

---@class TriggerBuilder
---@field parameters table
---@field settings table
local TB = {}
TB.__index = TB

local function copy(source)
	local out = {}
	for key, value in pairs(source or {}) do
		out[key] = value
	end
	return out
end

---@return TriggerBuilder
function TB.new()
	return setmetatable({ parameters = {}, settings = {} }, TB)
end

---@param self TriggerBuilder
---@param parameters table?
---@return TriggerBuilder
function TB:WithParameters(parameters)
	for name, value in pairs(parameters or {}) do
		self.parameters[name] = value
	end
	return self
end

---Settings are the mission-wide options (repeating, active, stages, ...) rather than
---the per-trigger parameters; Build() defaults the ones left out, as the loader does.
---@param self TriggerBuilder
---@param settings table?
---@return TriggerBuilder
function TB:WithSettings(settings)
	for name, value in pairs(settings or {}) do
		self.settings[name] = value
	end
	return self
end

---The raw, mission-authored table, before conditions_loader normalises it.
---@param self TriggerBuilder
---@return table
function TB:BuildRaw()
	return { parameters = copy(self.parameters), settings = copy(self.settings) }
end

---The trigger as conditions_loader's ProcessRawTriggers loads it.
---Each Build() hands out its own tables, so one builder can seed several triggers
---without them sharing state a handler might latch onto.
---@param self TriggerBuilder
---@return TriggerMock
function TB:Build()
	return conditionsLoader.ProcessRawTriggers({ trigger = self:BuildRaw() }).trigger
end

return TB
