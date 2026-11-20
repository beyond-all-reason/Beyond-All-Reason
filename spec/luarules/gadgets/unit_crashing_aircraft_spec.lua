local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function destroyAfter(elapsed, reason, tracked, normalDamage)
	local death = {
		[0] = normalDamage or 20,
		10,
		1,
		paralyzeDamageTime = 0,
		impulseFactor = 0.4,
		impulseBoost = 0,
		craterMult = 0.5,
		craterBoost = 0,
		craterAreaOfEffect = 24,
		damageAreaOfEffect = 24,
		edgeEffectiveness = 0,
		explosionSpeed = 2,
	}
	local selfD = { [0] = 310, 155, 12, damageAreaOfEffect = 48 }
	local original = table.copy(selfD)
	local crashing = tracked == false and {} or { [1] = 550 }
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
		GG = { Crashing = crashing },
		Game = { gameSpeed = 30, armorTypes = { "light", "heavy" }, envDamageTypes = { AircraftCrashed = -8 } },
		UnitDefs = {},
		WeaponDefNames = { commanderexplosion = { id = 99 } },
		COB = { CRASHING = 1 },
		Spring = {
			MoveCtrl = {},
			GetGameFrame = function()
				return 100 + elapsed
			end,
			GetUnitWeaponDamages = function(id, kind, key)
				assert.are.equal(1, id)
				assert.are.equal("explode", kind)
				return death[key]
			end,
			SetUnitWeaponDamages = function(id, kind, damages)
				assert.are.equal(1, id)
				assert.are.equal("selfDestruct", kind)
				for key, value in pairs(damages) do
					selfD[key] = value
				end
			end,
		},
	})
	SpecEnv.include(env, "luarules/gadgets/unit_crashing_aircraft.lua")
	env.gadget:UnitDestroyed(1, 1, 0, nil, nil, nil, reason)
	assert.is_nil(crashing[1])
	return selfD, death, original, env.gadget
end

describe("Aircraft crash explosion duration", function()
	for _, elapsed in ipairs({ 0, 29 }) do
		it("uses normal damage and radius after " .. elapsed .. " crashing frames", function()
			local actual, death = destroyAfter(elapsed, -8)
			assert.same(death, actual)
		end)
	end

	for _, elapsed in ipairs({ 30, 90 }) do
		it("keeps the full explosion after " .. elapsed .. " crashing frames", function()
			local actual, _, original = destroyAfter(elapsed, -8)
			assert.same(original, actual)
		end)
	end

	it("uses the unit's current normal explosion damage", function()
		local actual, death = destroyAfter(1, -8, true, 7)
		assert.same(death, actual)
	end)

	for _, reason in ipairs({ -10, -12 }) do
		it("leaves self-destruct and reclaimed deaths unchanged: " .. reason, function()
			local actual, _, original = destroyAfter(1, reason)
			assert.same(original, actual)
		end)
	end

	it("leaves untracked crashes unchanged", function()
		local actual, _, original = destroyAfter(1, -8, false)
		assert.same(original, actual)
	end)
end)
