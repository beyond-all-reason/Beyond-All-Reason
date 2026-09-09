local function loadCache(shared, state, transports)
	local calls = 0
	local env = setmetatable({
		gadget = {},
		rawget = false,
		rawset = false,
		GG = shared or {},
		Game = { gameSpeed = 30 },
		UnitDefs = { { transportCapacity = 0 }, { transportCapacity = 1 } },
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
		Spring = {
			GetAllUnits = function()
				return {}
			end,
			GetUnitTransporter = function() end,
			GetUnitIsDead = function(id)
				calls = calls + 1
				return state[id]
			end,
			GetUnitDefID = function(id)
				return transports and transports[id] and 2 or 1
			end,
		},
	}, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/api_unit_death_cache.lua"))
	setfenv(chunk, env)
	chunk()
	env.gadget:Initialize()
	return env.gadget, env.GG.IsUnitDead, function()
		return calls
	end
end

describe("Shared unit death cache", function()
	it("lazily caches live, dead and invalid IDs without treating false as a miss", function()
		local _, cache, calls = loadCache(nil, { [1] = false, [2] = true })
		for _ = 1, 20 do
			assert.is_false(cache[1])
			assert.is_true(cache[2])
			assert.is_true(cache[3])
		end
		assert.are.equal(3, calls())
	end)

	it("updates death synchronously and resets a reused ID", function()
		local state = { [1] = false }
		local gadget, cache = loadCache(nil, state)
		assert.is_false(cache[1])
		state[1] = true
		gadget:UnitDestroyed(1)
		assert.is_true(cache[1])
		gadget:GameFrame(300)
		state[1] = false
		gadget:UnitCreated(1, 1)
		assert.is_false(cache[1])
		gadget:GameFrame(600)
		assert.is_false(rawget(cache, 1))
	end)

	it("expunges dead and invalid entries after two rotations, preserving live entries", function()
		local gadget, cache, calls = loadCache(nil, { [1] = false })
		assert.is_false(cache[1])
		assert.is_true(cache[2])
		gadget:GameFrame(300)
		assert.is_true(rawget(cache, 2))
		gadget:GameFrame(599)
		assert.is_true(rawget(cache, 2))
		gadget:GameFrame(600)
		assert.is_nil(rawget(cache, 2))
		assert.is_false(rawget(cache, 1))
		assert.is_true(cache[2])
		assert.are.equal(3, calls())
	end)

	it("does not let an old death generation erase a new death of a reused ID", function()
		local state = { [1] = true }
		local gadget, cache = loadCache(nil, state)
		assert.is_true(cache[1])
		gadget:GameFrame(300)
		gadget:UnitCreated(1, 1)
		gadget:UnitDestroyed(1)
		gadget:GameFrame(600)
		assert.is_true(rawget(cache, 1))
		gadget:GameFrame(900)
		assert.is_nil(rawget(cache, 1))
	end)

	it("queries transports until dead, including before their UnitDestroyed callback", function()
		local state = { [1] = false }
		local gadget, cache, calls = loadCache(nil, state, { [1] = true })
		assert.is_false(cache[1]) -- existing transport after reload, no UnitCreated
		assert.is_nil(rawget(cache, 1))
		state[1] = true -- cargo callbacks precede transporter UnitDestroyed
		assert.is_true(cache[1])
		assert.are.equal(2, calls())
		gadget:UnitDestroyed(1)
		state[1] = false
		gadget:UnitCreated(1, 2)
		assert.is_false(cache[1])
		assert.is_nil(rawget(cache, 1))
	end)

	it("invalidates an ordinary unit when Lua forces it to carry cargo", function()
		local state = { [1] = false }
		local gadget, cache = loadCache(nil, state)
		assert.is_false(cache[1])
		gadget:UnitLoaded(2, 1, 0, 1)
		assert.is_nil(rawget(cache, 1))
		assert.is_false(cache[1])
		state[1] = true
		assert.is_true(cache[1])
	end)

	it("preserves consumer references and queries current engine state on reload", function()
		local shared, state = {}, { [1] = false }
		local first, cache = loadCache(shared, state)
		assert.is_false(cache[1])
		first:Shutdown()
		state[1] = true
		assert.is_true(cache[1])
		assert.is_nil(rawget(cache, 1))
		state[1] = false
		assert.is_false(cache[1])
		local _, reloaded = loadCache(shared, state)
		assert.is_true(cache == reloaded)
		assert.is_false(cache[1])
	end)

	it("acquires a table created earlier by a consumer", function()
		local shared = { IsUnitDead = {} }
		local consumer = shared.IsUnitDead
		local _, cache = loadCache(shared, {})
		assert.is_true(cache == consumer)
		assert.is_true(consumer[17])
	end)
end)
