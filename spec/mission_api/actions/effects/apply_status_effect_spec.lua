local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = MissionSpecEnv.include(env, "luarules/mission_api/parameter_types.lua")

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/effects/apply_status_effect.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.apply_status_effect", function()
	it("declares its type and parameters", function()
		assert.are.same({
			type = "ApplyStatusEffect",
			effectType = "EffectType!",
			effectName = "EffectName!",
			area = "Area!",
			duration = "Quantity",
			strength = "PositiveInteger",
		}, summarizeSchema(action))
	end)
end)
