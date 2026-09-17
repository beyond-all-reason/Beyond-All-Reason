local Export = VFS.Include("modules/start/lib/export.lua") ---@type StartExport

local square = { { x = 0, z = 0 }, { x = 500, z = 0 }, { x = 500, z = 500 }, { x = 0, z = 500 } }

describe("the startbox arrangement export", function()
	it("normalises anchors to 0..200, ships a rect as two corners, and snaps strength", function()
		local out = Export.Arrangement({
			{ team = 1, kind = "box", vertices = square },
			{
				team = 2,
				kind = "spline",
				controls = {
					{ x = 1000, z = 1000, strength = 0.51 },
					{ x = 1000, z = 500, strength = 0.01 },
					{ x = 500, z = 500 },
				},
			},
		}, 1000, 1000)
		assert.are.same({ { x = 0, y = 0 }, { x = 100, y = 100 } }, out[1].poly)
		assert.are.same({ x = 200, y = 200, strength = 0.5 }, out[2].poly[1])
		assert.is_nil(out[2].poly[2].strength, "a strength that rounds to zero is omitted")
	end)
end)

describe("the start script", function()
	it("gives each team its areas' bounding rect, one AI per team past the first, and the mod options", function()
		local script = assert(Export.StartScript({
			{ team = 1, vertices = square },
			{ team = 2, vertices = { { x = 500, z = 500 }, { x = 1000, z = 1000 } } },
		}, 1000, 1000, { mapName = "Some Map", modOptions = { deathmode = "neverend" } }))
		assert.matches("startrectright = 0.50000000;", script)
		assert.matches("%[allyTeam1%]", script)
		assert.matches("%[ai0%]", script)
		assert.matches("deathmode = neverend;", script)
		assert.matches("mapname = Some Map;", script)
		assert.is_nil(Export.StartScript({}, 1000, 1000, { mapName = "m" }))
	end)
end)
