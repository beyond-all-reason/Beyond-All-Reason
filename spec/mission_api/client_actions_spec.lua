require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local clientActions = VFS.Include("luarules/mission_api/client_actions.lua")

describe("mission_api.client_actions", function()
	---@type table<string, integer[]>
	local unitsByName
	---@type table[]
	local sent
	local originalGetUnitPosition = Spring.GetUnitPosition

	before_each(function()
		unitsByName = { hero = { 11 }, raiders = { 21, 22 }, mixed = { 22, 31 } }
		sent = {}
		Builders.MissionApi
			.new()
			:WithModule("UnitQuery", {
				MatchingUnits = function(unitName)
					return unitsByName[unitName] or {}
				end,
			})
			:Install()
		_G.SendToUnsynced = function(action, command) ---@diagnostic disable-line: global-in-non-module
			sent[#sent + 1] = { action = action, command = command }
		end
		-- unit n stands at (10n, 5, 20n); base, mid and aim positions alike
		Spring.GetUnitPosition = function(unitID)
			local x, y, z = unitID * 10, 5, unitID * 20
			return x, y, z, x, y, z, x, y, z
		end
	end)

	after_each(function()
		Spring.GetUnitPosition = originalGetUnitPosition
	end)

	describe("BuildTarget", function()
		it("passes a position through", function()
			assert.are.same({ x = 1, y = 2, z = 3 }, clientActions.BuildTarget(nil, nil, { x = 1, y = 2, z = 3 }))
		end)

		it("resolves one name to its units, seeded with where they stand", function()
			assert.are.same(
				{ unitIDs = { 21, 22 }, lastX = 215, lastY = 5, lastZ = 430 },
				clientActions.BuildTarget("raiders")
			)
		end)

		it("joins a name and a list of names, each unit once", function()
			assert.are.same(
				{ unitIDs = { 11, 21, 22, 31 }, lastX = 212.5, lastY = 5, lastZ = 425 },
				clientActions.BuildTarget("hero", { "raiders", "mixed" })
			)
		end)

		it("gives an unknown name no units and no seed", function()
			assert.are.same({ unitIDs = {} }, clientActions.BuildTarget("nobody"))
		end)

		it("carries the offset along", function()
			assert.are.same({
				unitIDs = { 11 },
				lastX = 110,
				lastY = 5,
				lastZ = 220,
				offset = { x = 0, y = 50, z = -200 },
				relativeToHeading = true,
			}, clientActions.BuildTarget("hero", nil, nil, { x = 0, y = 50, z = -200 }, true))
		end)
	end)

	describe("BuildKeyframes", function()
		it("turns the flat authored fields into the widget's targets", function()
			local authored = {
				{
					unitName = "hero",
					offsetZ = -200,
					offsetY = 100,
					relativeToHeading = true,
					lookAtUnitNames = { "raiders" },
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
			}, clientActions.BuildKeyframes(authored))
			assert.is_nil(authored[1].position) -- the mission's own table is left alone
		end)
	end)

	describe("Send", function()
		it("sends one command table to every client", function()
			clientActions.Send("shake", { magnitude = 10 }, 1)
			assert.are.same({
				{
					action = "MissionClientAction",
					command = { kind = "shake", teamID = 1, params = { magnitude = 10 } },
				},
			}, sent)
		end)
	end)
end)
