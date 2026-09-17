local Start = VFS.Include("modules/start/api.lua") ---@type StartApi

local function stubSpring(positions, rects)
	return {
		GetAllyTeamList = function()
			local ids = {}
			for id in pairs(rects or {}) do
				ids[#ids + 1] = id
			end
			table.sort(ids)
			return ids
		end,
		GetAllyTeamStartBox = function(id)
			local r = rects and rects[id]
			if r then
				return r[1], r[2], r[3], r[4]
			end
			return 0, 0, 0, 0
		end,
		GetModOptions = function()
			return {}
		end,
		GetGaiaTeamID = function()
			return 99
		end,
		GetTeamList = function()
			local ids = { 99 }
			for _, p in ipairs(positions) do
				ids[#ids + 1] = p.teamID
			end
			return ids
		end,
		GetTeamStartPosition = function(teamID)
			for _, p in ipairs(positions) do
				if p.teamID == teamID then
					return p.x, 0, p.z
				end
			end
			return 0, 0, 0
		end,
		GetTeamAllyTeamID = function(teamID)
			for _, p in ipairs(positions) do
				if p.teamID == teamID then
					return p.allyTeamID
				end
			end
			return nil
		end,
	}
end

describe("the match's starts", function()
	it("are the resolver's boxes by ally team, whole-map fallbacks left out, and the engine's positions", function()
		local resolver = function()
			return {
				byAllyTeam = {
					[0] = { boxes = { { { 0, 0 }, { 100, 0, 0.5 }, { 100, 100 } } } },
					[1] = { boxes = { { { 0, 0 }, { 1, 1 }, { 2, 2 }, { 3, 3 } } }, wholeMap = true },
					[2] = { boxes = { { { 500, 500 }, { 600, 500 }, { 600, 600 }, { 500, 600 } } } },
				},
				source = "modoption_set",
				explicit = true,
			}
		end
		local current = Start.Current(
			stubSpring({
				{ teamID = 0, allyTeamID = 0, x = 50, z = 50 },
				{ teamID = 1, allyTeamID = 2, x = 550, z = 550 },
				{ teamID = 2, allyTeamID = 1, x = 0, z = 0 },
			}),
			resolver
		)
		assert.are.equal(2, #current.areas)
		assert.are.equal(1, current.areas[1].allyTeam)
		assert.are.equal(3, current.areas[2].allyTeam)
		assert.are.equal(0.5, current.areas[1].anchors[2].strength)
		assert.are.equal("modoption_set", current.areas[1].source)
		assert.are.equal(2, #current.positions)
		assert.are.same({ allyTeam = 3, teamID = 1, x = 550, z = 550 }, current.positions[2])
	end)

	it("takes the engine's rects when no modoption set the boxes, a whole-map rect being no box", function()
		_G.Game.mapSizeX, _G.Game.mapSizeZ = 4000, 4000
		local spring = stubSpring(
			{},
			{ [0] = { 0, 0, 800, 800 }, [1] = { 3200, 3200, 4000, 4000 }, [2] = { 0, 0, 4000, 4000 } }
		)
		local current = Start.Current(spring, function()
			return {
				byAllyTeam = { [0] = { boxes = { { { 0, 0 }, { 1, 0 }, { 1, 1 } } } } },
				source = "fallback",
				explicit = false,
			}
		end)
		assert.are.equal(2, #current.areas)
		assert.are.equal("engine", current.areas[1].source)
		assert.are.equal(800, current.areas[1].anchors[3].x)
		assert.are.equal(2, current.areas[2].allyTeam)
	end)

	it("has no areas when the resolver and the engine have nothing", function()
		local current = Start.Current(stubSpring({}), function()
			return { explicit = false }
		end)
		assert.are.same({}, current.areas)
		assert.are.same({}, current.positions)
	end)
end)
