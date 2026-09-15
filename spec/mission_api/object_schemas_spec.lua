---
--- The schemas describing the objects a mission declares itself. They are data for tools,
--- the mission editor included, so these checks pin the shape they promise.
---

require("spec_helper")

local parameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
local Types = parameterTypes.Types

local objectivesSchema = VFS.Include("luarules/mission_api/objectives_schema.lua")
local triggersSchema = VFS.Include("luarules/mission_api/triggers_schema.lua")
local countdownsSchema = VFS.Include("luarules/mission_api/countdowns_schema.lua")

describe("mission_api object schemas", function()
	--- A type a validator does not know is silently accepted, so the schema would promise
	--- a shape nothing enforces.
	it("uses only declared parameter types", function()
		local unknown = {}
		for schemaName, schema in pairs({
			objectives_schema = objectivesSchema,
			triggers_schema = triggersSchema,
			countdowns_schema = countdownsSchema,
		}) do
			for fieldName, fieldType in pairs(schema.Settings) do
				if Types[fieldType] == nil then
					unknown[#unknown + 1] = schemaName .. "." .. fieldName .. " (" .. tostring(fieldType) .. ")"
				end
			end
		end
		table.sort(unknown)

		assert.are.same({}, unknown)
	end)

	it("describes an objective's fields", function()
		assert.are.same({
			textKey = Types.String,
			trigger = Types.Table,
			amount = Types.Quantity,
			nextStage = Types.StageID,
			coop = Types.Boolean,
			hidden = Types.Boolean,
			onActivated = Types.TriggerID,
			onCanceled = Types.TriggerID,
			onProgress = Types.TriggerID,
			onCompleted = Types.TriggerID,
			onFailed = Types.TriggerID,
		}, objectivesSchema.Settings)
	end)

	it("describes the settings every trigger shares", function()
		assert.are.same({
			prerequisites = Types.TriggerIDs,
			repeating = Types.Boolean,
			maxRepeats = Types.Quantity,
			difficulties = Types.Table,
			coop = Types.Boolean,
			active = Types.Boolean,
			stages = Types.StageIDs,
		}, triggersSchema.Settings)
	end)

	-- The defaults triggers_loader applies must be settings the schema declares, or a raw
	-- mission and a loaded one would disagree about a trigger's shape.
	it("declares every setting the trigger loader defaults", function()
		local defaulted = { "prerequisites", "repeating", "coop", "active", "stages" }

		for _, settingName in ipairs(defaulted) do
			assert.is_not_nil(
				triggersSchema.Settings[settingName],
				"triggers_schema is missing the defaulted setting '" .. settingName .. "'"
			)
		end
	end)
end)
