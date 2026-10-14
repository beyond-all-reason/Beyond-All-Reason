require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local camera = VFS.Include("luarules/mission_api/camera.lua")

describe("mission_api.camera", function()
	local originalGetUnitArrayCentroid = Spring.GetUnitArrayCentroid

	before_each(function()
		local unitsByName = { hero = { 11 }, raiders = { 21, 22 } }
		Builders.MissionApi
			.new()
			:WithModule("UnitQuery", {
				MatchingUnits = function(unitName)
					return unitsByName[unitName] or {}
				end,
			})
			:Install()
		-- unit n stands at (10n, 5, 20n)
		Spring.GetUnitArrayCentroid = function(unitIDs)
			if #unitIDs == 0 then
				return nil, nil, nil
			end
			local x, z = 0.0, 0.0
			for _, unitID in ipairs(unitIDs) do
				x, z = x + unitID * 10, z + unitID * 20
			end
			return x / #unitIDs, 5, z / #unitIDs
		end
	end)

	after_each(function()
		Spring.GetUnitArrayCentroid = originalGetUnitArrayCentroid
	end)

	describe("BuildTarget", function()
		it("passes a position through", function()
			assert.are.same({ x = 1, y = 2, z = 3 }, camera.BuildTarget(nil, { x = 1, y = 2, z = 3 }))
		end)

		it("resolves a name to all its units, starting from where they stand", function()
			assert.are.same(
				{ unitIDs = { 21, 22 }, lastX = 215, lastY = 5, lastZ = 430 },
				camera.BuildTarget("raiders")
			)
		end)

		it("gives a name without living units no units and no starting point", function()
			assert.are.same({ unitIDs = {} }, camera.BuildTarget("nobody"))
		end)

		it("carries the offset along", function()
			assert.are.same({
				unitIDs = { 11 },
				lastX = 110,
				lastY = 5,
				lastZ = 220,
				offset = { x = 0, y = 50, z = -200 },
				relativeToHeading = true,
			}, camera.BuildTarget("hero", nil, { x = 0, y = 50, z = -200 }, true))
		end)
	end)

	describe("BuildKeyframes", function()
		it("turns the flat keyframe fields into targets", function()
			local authored = {
				{
					unitName = "hero",
					offsetZ = -200,
					offsetY = 100,
					relativeToHeading = true,
					lookAtUnitName = "raiders",
					duration = 3,
					easing = "linear",
					path = "spline",
				},
				{ position = { x = 10, y = 20, z = 30 }, lookAtPosition = { x = 0, y = 0, z = 0 }, hold = 1 },
				{ position = { x = 1, y = 2, z = 3 }, pitch = 45, yaw = 90, roll = 5, fov = 60 },
			}

			assert.are.same({
				{
					position = {
						unitIDs = { 11 },
						lastX = 110,
						lastY = 5,
						lastZ = 220,
						offset = { x = 0, y = 100, z = -200 },
						relativeToHeading = true,
					},
					lookAt = { unitIDs = { 21, 22 }, lastX = 215, lastY = 5, lastZ = 430 },
					duration = 3,
					easing = "linear",
					path = "spline",
				},
				{ position = { x = 10, y = 20, z = 30 }, lookAt = { x = 0, y = 0, z = 0 }, hold = 1 },
				{ position = { x = 1, y = 2, z = 3 }, pitch = 45, yaw = 90, roll = 5, fov = 60 },
			}, camera.BuildKeyframes(authored))
			assert.is_nil(authored[1].position) -- the mission's own table is left alone
		end)
	end)
end)
