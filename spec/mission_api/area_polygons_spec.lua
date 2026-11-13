local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()
local areaPolygons = MissionSpecEnv.include(env, "luarules/mission_api/area_polygons.lua")

describe("mission_api.area_polygons", function()
	it("gives a rectangle its four corners", function()
		local polygon = areaPolygons.FromArea({ x1 = 100, z1 = 200, x2 = 300, z2 = 400 })
		assert.are.same({ 100, 200, 300, 200, 300, 400, 100, 400 }, polygon)
	end)

	it("gives a circle 32 vertices, starting east of its centre", function()
		local polygon = areaPolygons.FromArea({ x = 1000, z = 2000, radius = 500 })
		assert.are.equal(64, #polygon)
		assert.are.same({ 1500, 2000 }, { polygon[1], polygon[2] })
	end)

	it("puts a circle's vertices on whole elmos at its radius", function()
		local polygon = areaPolygons.FromArea({ x = 1000, z = 2000, radius = 500 })
		for i = 1, #polygon, 2 do
			local distance = math.sqrt((polygon[i] - 1000) ^ 2 + (polygon[i + 1] - 2000) ^ 2)
			assert.is_true(math.abs(distance - 500) < 1)
			assert.are.equal(math.floor(polygon[i]), polygon[i])
		end
	end)

	it("keeps the vertices inside the map", function()
		local polygon = areaPolygons.FromArea({ x1 = -100, z1 = -50, x2 = Game.mapSizeX + 900, z2 = 300 })
		assert.are.same({ 0, 0, Game.mapSizeX, 0, Game.mapSizeX, 300, 0, 300 }, polygon)
	end)
end)
