-- Builds a raw mission table, using the shape a mission file returns.
-- This is the input to validation, before the loaders modify it, so it is
-- deliberately separate from mission_api_builder.lua, which mocks the loaded
-- GG['MissionAPI'] state.

---@class MissionBuilder
local MB = {}
MB.__index = MB

---@return MissionBuilder
function MB.new()
    return setmetatable({
        fields = {
            Stages         = {},
            Objectives     = {},
            Triggers       = {},
            Actions        = {},
            UnitLoadout    = {},
            FeatureLoadout = {},
        },
    }, MB)
end

---@param self MissionBuilder
---@param stageID string
---@return MissionBuilder
function MB:WithInitialStage(stageID)
    self.fields.InitialStage = stageID
    return self
end

---@param self MissionBuilder
---@param stageID string
---@param stage table objectives table, or the whole stage
---@return MissionBuilder
function MB:WithStage(stageID, stage)
    self.fields.Stages[stageID] = stage or { objectives = {} }
    return self
end

---Sets the stage and makes it the initial one, for missions with a single stage.
---@param self MissionBuilder
---@param stageID string
---@param stage table
---@return MissionBuilder
function MB:WithInitialStageDefinition(stageID, stage)
    return self:WithStage(stageID, stage):WithInitialStage(stageID)
end

---@param self MissionBuilder
---@param objectiveID string
---@param objective table
---@return MissionBuilder
function MB:WithObjective(objectiveID, objective)
    self.fields.Objectives[objectiveID] = objective or {}
    return self
end

---@param self MissionBuilder
---@param triggerID string
---@param trigger table
---@return MissionBuilder
function MB:WithTrigger(triggerID, trigger)
    self.fields.Triggers[triggerID] = trigger or {}
    return self
end

---@param self MissionBuilder
---@param actionID string
---@param action table
---@return MissionBuilder
function MB:WithAction(actionID, action)
    self.fields.Actions[actionID] = action or {}
    return self
end

---@param self MissionBuilder
---@param loadout table
---@return MissionBuilder
function MB:WithUnitLoadout(loadout)
    self.fields.UnitLoadout = loadout
    return self
end

---@param self MissionBuilder
---@param loadout table
---@return MissionBuilder
function MB:WithFeatureLoadout(loadout)
    self.fields.FeatureLoadout = loadout
    return self
end

---Sets a top level field directly, for missions that declare one incorrectly.
---@param self MissionBuilder
---@param field string
---@param value any
---@return MissionBuilder
function MB:WithField(field, value)
    self.fields[field] = value
    return self
end

---Each call returns an independent mission, so a built mission is a snapshot of the
---builder. The entries themselves are shared, since specs treat them as read only.
---@param self MissionBuilder
---@return table raw mission table
function MB:Build()
    local mission = {}
    for field, value in pairs(self.fields) do
        if type(value) == 'table' then
            local section = {}
            for key, entry in pairs(value) do
                section[key] = entry
            end
            mission[field] = section
        else
            mission[field] = value
        end
    end
    return mission
end

return MB
