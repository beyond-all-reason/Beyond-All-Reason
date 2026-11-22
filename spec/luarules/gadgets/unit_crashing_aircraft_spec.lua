local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function crash(options)
	local death = {
		[0] = 20,
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
	local selfD = table.copy(death)
	selfD[0], selfD[1], selfD[2] = 310, 110, 11
	selfD.damageAreaOfEffect, selfD.impulseFactor = 48, 1.2
	local original = table.copy(selfD)
	local crashing = {}
	local frame = 100
	local noop = function() end
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
		GG = { Crashing = crashing, UnitAttributes = { SetUnitAttribute = noop, SetUnitModifier = noop } },
		SendToUnsynced = noop,
		Game = { gameSpeed = 30, armorTypes = { "light", "heavy" }, envDamageTypes = { AircraftCrashed = -8 } },
		UnitDefs = {
			{
				id = 1,
				canFly = true,
				canSubmerge = options.submerges,
				buildSpeed = 0,
				weapons = {},
				customParams = options.params or {},
			},
		},
		WeaponDefNames = { commanderexplosion = { id = 99 } },
		COB = { CRASHING = 1 },
		Spring = {
			MoveCtrl = {},
			GetUnitHealth = function()
				return 100
			end,
			GetUnitMoveTypeData = function()
				return { aircraftState = options.state or "flying" }
			end,
			GetUnitPosition = function()
				return 0, options.y or 0, 0
			end,
			GetGroundHeight = function()
				return options.ground or 0
			end,
			GetUnitVelocity = function()
				return 12, options.vy or 0, 0
			end,
			SetUnitCOBValue = noop,
			SetUnitNoSelect = noop,
			SetUnitNoMinimap = noop,
			SetUnitIconDraw = noop,
			SetUnitAlwaysVisible = noop,
			SetUnitNeutral = noop,
			SetUnitBlocking = noop,
			SetUnitCrashing = noop,
			GetGameFrame = function()
				return frame
			end,
			GetUnitWeaponDamages = function(id, kind, key)
				assert.are.equal(1, id)
				return (kind == "explode" and death or selfD)[key]
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
	if not options.untracked then
		env.gadget:UnitPreDamaged(1, 1, 0, 120, false, 5)
	end
	frame = frame + (options.frames or 0)
	env.gadget:UnitDestroyed(1, 1, 0, nil, nil, nil, options.reason or -8)
	assert.is_nil(crashing[1])
	return selfD, death, original
end

describe("Aircraft crash explosions", function()
	it("uses normal explosion damage and radius when shot on the ground", function()
		local actual, normal = crash({ state = "landed", frames = 40 })
		assert.same(normal, actual)
	end)

	for _, state in ipairs({ "takeoff", "hovering", "flying", "landing" }) do
		it("keeps the full explosion for an immediate impact during " .. state, function()
			local actual, _, full = crash({ state = state })
			assert.same(full, actual)
		end)
	end

	it("distinguishes floating on water from an aircraft spawned above its landing surface", function()
		local floating, normal = crash({ state = "landed", y = 0, ground = -50 })
		assert.same(normal, floating)
		local airborne, _, full = crash({ state = "landed", y = 40 })
		assert.same(full, airborne)
		local submerged, seabed = crash({ state = "landed", y = -50, ground = -50, submerges = true })
		assert.same(seabed, submerged)
	end)

	local curve = { crash_damage_speed_min = "1", crash_damage_speed_max = "5", crash_damage_exponent = "2" }
	it("uses signed impact velocity, clamps both ends, and keeps grounded hits normal", function()
		for _, vy in ipairs({ 3, 0, -1 }) do
			local actual, normal = crash({ params = curve, vy = vy, frames = 90 })
			assert.same(normal, actual)
		end
		local fast, _, full = crash({ params = curve, vy = -7 })
		assert.same(full, fast)
		local landed, normal = crash({ state = "landed", params = curve, vy = -7 })
		assert.same(normal, landed)
	end)

	it("interpolates each armor class, the blast radius and impulse using the configured exponent", function()
		local actual = crash({ params = curve, vy = -3 })
		assert.equal(92.5, actual[0])
		assert.equal(35, actual[1])
		assert.equal(3.5, actual[2])
		assert.equal(30, actual.damageAreaOfEffect)
		assert.near(0.6, actual.impulseFactor, 0.000001)
	end)

	it("defaults to a linear curve starting at zero when only the full-damage speed is set", function()
		local actual = crash({ params = { crash_damage_speed_max = "4" }, vy = -2 })
		assert.equal(165, actual[0])
		assert.equal(36, actual.damageAreaOfEffect)
	end)

	it("falls back to the airborne default for a reversed speed interval", function()
		local actual, _, full = crash({ params = { crash_damage_speed_min = "5", crash_damage_speed_max = "2" } })
		assert.same(full, actual)
	end)

	for _, options in ipairs({
		{ state = "landed", reason = -10 },
		{ state = "landed", reason = -12 },
		{ state = "landed", untracked = true },
	}) do
		it("preserves the original profile for " .. (options.reason or "untracked impact"), function()
			local actual, _, full = crash(options)
			assert.same(full, actual)
		end)
	end
end)
