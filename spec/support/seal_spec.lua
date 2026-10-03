---@diagnostic disable: inject-field

local SHARED = { "Spring", "VFS", "Game", "io", "CMD", "GameCMD", "LOG", "Json", "string", "table", "math", "os" }

-- Must match spec_helper's seed, which is neither Lua's nor LuaJIT's default state.
local HELPER_SEED = 12345

local firstRandom = math.random()

describe("the tables spec files share", function()
	it("refuse a write to any of them", function()
		for _, name in ipairs(SHARED) do
			assert.error_matches(function()
				_G[name].SealProbe = true
			end, name .. "%.SealProbe is shared")
		end
	end)

	it("refuse a write to a table nested inside one", function()
		assert.error_matches(function()
			Game.envDamageTypes.SealProbe = -99
		end, "Game%.envDamageTypes%.SealProbe is shared")

		assert.is_nil(Game.envDamageTypes.SealProbe)
	end)

	it("let through a write of the value already there", function()
		assert.is_true(pcall(function()
			string.format = string.format
		end))
	end)

	it("refuse to be enumerated", function()
		assert.error_matches(function()
			pairs(Spring)
		end, "Spring is sealed")
		assert.error_matches(function()
			next(Game.envDamageTypes)
		end, "Game%.envDamageTypes is sealed")
		assert.error_matches(function()
			ipairs(table)
		end, "table is sealed")
	end)

	it("carry the common extensions the game loads at startup", function()
		assert.are.same({ "a", "b" }, ("a,b"):split(","))
	end)
end)

describe("each spec file", function()
	it("gets a GG it can write", function()
		GG.SealProbe = true

		assert.is_true(GG.SealProbe)
	end)

	it("starts from the same random stream", function()
		math.randomseed(HELPER_SEED)

		assert.are.equal(firstRandom, math.random())
	end)
end)
