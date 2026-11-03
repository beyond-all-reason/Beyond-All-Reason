GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = VFS.Include("luarules/mission_api/actions/environment/set_map_lighting.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.set_map_lighting", function()
	local calls

	before_each(function()
		calls = {}
		GG.MapLighting = {
			SetLighting = function(values, duration)
				calls[#calls + 1] = { values, duration }
			end,
		}
	end)

	after_each(function()
		GG.MapLighting = nil
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "SetMapLighting",
			brightness = "Quantity",
			tint = "Color",
			sunAzimuth = "Number",
			sunElevation = "Number",
			groundAmbientColor = "Color",
			groundDiffuseColor = "Color",
			groundSpecularColor = "Color",
			unitAmbientColor = "Color",
			unitDiffuseColor = "Color",
			unitSpecularColor = "Color",
			groundShadowDensity = "Fraction",
			unitShadowDensity = "Fraction",
			transitionDuration = "Quantity",
			requiresOneOf = {
				"brightness",
				"tint",
				"sunAzimuth",
				"sunElevation",
				"groundAmbientColor",
				"groundDiffuseColor",
				"groundSpecularColor",
				"unitAmbientColor",
				"unitDiffuseColor",
				"unitSpecularColor",
				"groundShadowDensity",
				"unitShadowDensity",
			},
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		-- The dispatcher passes the parameters in schema order.
		local function callWith(parameters)
			local values = {}
			for i, parameter in ipairs(action.parameters) do
				values[i] = parameters[parameter.name]
			end
			action.actionFunction(unpack(values, 1, #action.parameters))
		end

		it("passes only the given values, with the transition duration", function()
			callWith({
				brightness = 0.5,
				tint = { 1, 0.8, 0.6 },
				groundDiffuseColor = { 0.2, 0.3, 0.9 },
				groundShadowDensity = 0.4,
				transitionDuration = 3,
			})

			assert.are.same({
				{
					{
						brightness = 0.5,
						tint = { 1, 0.8, 0.6 },
						groundDiffuseColor = { 0.2, 0.3, 0.9 },
						groundShadowDensity = 0.4,
					},
					3,
				},
			}, calls)
		end)

		it("passes no duration when none is given", function()
			callWith({ sunAzimuth = 90, sunElevation = 15 })

			assert.are.same({ { { sunAzimuth = 90, sunElevation = 15 } } }, calls)
		end)
	end)
end)
