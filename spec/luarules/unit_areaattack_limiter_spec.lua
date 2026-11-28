local function loadLimiter(targetCount)
	local selected, orders, targets = {}, {}, {}
	for id = 1, 40 do
		selected[id] = id
	end
	for id = 1, targetCount do
		targets[id] = 100 + id
	end
	local env = setmetatable({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return false
			end,
		},
		BAR = { Utilities = {
			GetObjectCentroid = function()
				return 0, 0
			end,
		} },
		CMD = { ATTACK = 20, FIGHT = 16, STOP = 0, OPT_SHIFT = 32 },
		UnitDefs = { { customParams = {}, weapons = {} } },
		WeaponDefs = {},
		CallAsTeam = function(_, fn)
			return fn()
		end,
		Spring = {
			ENEMY_UNITS = -4,
			GetSelectedUnits = function()
				return selected
			end,
			GetUnitDefID = function()
				return 1
			end,
			GetUnitNeutral = function()
				return false
			end,
			GetUnitCommands = function()
				return {}
			end,
			GetUnitPosition = function(id)
				return id, 0, id
			end,
			GetUnitsInCylinder = function()
				return targets
			end,
			GetLocalTeamID = function()
				return 0
			end,
			GiveOrderArrayToUnit = function(unitID, commands)
				orders[#orders + 1] = { unitID = unitID, commands = commands }
			end,
		},
		require = function(name)
			if name == "modules/split_targets" then
				return {
					Rivers = function(units, unitTargets)
						local assignments = {}
						for _, unitID in ipairs(units) do
							assignments[unitID] = unitTargets
						end
						return assignments, { units }
					end,
				}
			end
			return require(name)
		end,
	}, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/unit_areaattack_limiter.lua"))
	setfenv(chunk, env)
	chunk()
	return env.gadget, orders
end

describe("raw area attack limiter", function()
	for _, params in ipairs({ { 10, 20, 30, 100 }, { 0, 0, 0, 20, 40, 60 } }) do
		it("splits a large " .. #params .. "-parameter raw Attack", function()
			local gadget, orders = loadLimiter(60)
			assert.is_true(gadget:GetInfo().enabled)
			assert.is_true(gadget:CommandNotify(20, params, { shift = true }))
			assert.are.equal(40, #orders)
			assert.are.equal(1, orders[1].unitID)
			assert.same({ 20, { 101 }, 32 }, orders[1].commands[1])
		end)
	end

	it("leaves smaller area Attacks and other command IDs alone", function()
		local gadget, orders = loadLimiter(2)
		assert.is_false(gadget:CommandNotify(20, { 10, 20, 30, 100 }, {}))
		assert.is_nil(gadget:CommandNotify(21, { 10, 20, 30, 100 }, {}))
		assert.same({}, orders)
	end)
end)
