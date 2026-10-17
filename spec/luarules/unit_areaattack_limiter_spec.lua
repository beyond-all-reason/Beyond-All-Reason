local function loadLimiter()
	local selected, orders = {}, {}
	for id = 1, 40 do
		selected[id] = id
	end
	local env = setmetatable({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return false
			end,
		},
		CMD = { ATTACK = 20, FIGHT = 16, STOP = 0, OPT_SHIFT = 32 },
		UnitDefs = { { customParams = {}, weapons = {} } },
		WeaponDefs = {},
		CallAsTeam = function(_, fn)
			return fn()
		end,
		Spring = {
			GetSelectedUnits = function()
				return selected
			end,
			GetUnitDefID = function()
				return 1
			end,
			GetLocalTeamID = function()
				return 0
			end,
			SelectUnitArray = function(units)
				selected = units
			end,
			GiveOrder = function(id, params, options)
				orders[#orders + 1] = { id = id, params = params, options = options, count = #selected }
			end,
		},
	}, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/unit_areaattack_limiter.lua"))
	setfenv(chunk, env)
	chunk()
	return env.gadget, orders
end

describe("raw area attack limiter", function()
	for _, params in ipairs({ { 10, 20, 30, 100 }, { 0, 0, 0, 20, 40, 60 } }) do
		it("limits a " .. #params .. "-parameter raw Attack", function()
			local gadget, orders = loadLimiter()
			assert.is_true(gadget:GetInfo().enabled)
			assert.is_true(gadget:CommandNotify(20, params, { shift = true }))
			assert.are.equal(2, #orders)
			assert.are.equal(20, orders[1].id)
			assert.are.equal(30, orders[1].count)
			assert.same(params, orders[1].params)
			assert.are.equal(16, orders[2].id)
			assert.are.equal(10, orders[2].count)
			assert.same({ 10, 20, 30 }, orders[2].params)
		end)
	end

	it("leaves compact lists and engine-native Area Attack alone", function()
		local gadget, orders = loadLimiter()
		gadget:CommandNotify(GameCMD.ATTACK_TARGETS, { 1, 2, 3, 4 }, {})
		gadget:CommandNotify(21, { 10, 20, 30, 100 }, {})
		assert.same({}, orders)
	end)
end)
