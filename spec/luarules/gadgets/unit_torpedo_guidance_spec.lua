---@diagnostic disable: undefined-field

local GADGET_PATH = "luarules/gadgets/unit_torpedo_guidance.lua"
local PROJECTILE_ID = 1
local WEAPON_DEF_ID = 1

local function loadGadget(mode, avoidLeavingWater)
	local shot = { height = -5, velocityX = 8, velocityY = -2, ttl = 10, targetHeight = 0 }
	local function magnitude(x, y, z)
		return math.sqrt(x * x + y * y + (z or 0) ^ 2)
	end
	local env = {
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RegisterProjectile = function() end,
		},
		math = setmetatable({
			diag = magnitude,
			clamp = function(value, lower, upper)
				return math.max(lower, math.min(value, upper))
			end,
		}, { __index = math }),
		CallAsTeam = function(_, fn, ...)
			return fn(...)
		end,
		WeaponDefs = {
			[WEAPON_DEF_ID] = {
				tracks = true,
				turnRate = 0.025,
				customParams = { torpedo_guidance = mode, avoid_leaving_water = avoidLeavingWater },
			},
		},
		Spring = {
			GetGroundHeight = function()
				return -100
			end,
			GetProjectileDefID = function()
				return WEAPON_DEF_ID
			end,
			GetProjectilePosition = function()
				return 0, shot.height, 0
			end,
			GetProjectileTarget = function()
				if shot.groundTarget then
					return string.byte("g"), { 300, shot.targetHeight, 0 }
				end
				return string.byte("u"), 10
			end,
			GetProjectileTeamID = function()
				return 0
			end,
			GetProjectileTimeToLive = function()
				return shot.ttl
			end,
			GetProjectileVelocity = function()
				return shot.velocityX, shot.velocityY, 0, magnitude(shot.velocityX, shot.velocityY)
			end,
			GetUnitPosition = function()
				return 300, shot.targetHeight, 0, 300, shot.targetHeight, 0
			end,
			GetUnitVelocity = function()
				return 0, 0, 0
			end,
			SetProjectileVelocity = function(_, x, y)
				shot.velocityX, shot.velocityY = x, y
			end,
		},
	}
	setmetatable(env, { __index = _G })
	local chunk = assert(loadfile(GADGET_PATH))
	setfenv(chunk, env)
	chunk()
	env.gadget:Initialize()
	env.gadget:ProjectileCreated(PROJECTILE_ID, nil, WEAPON_DEF_ID)
	return env.gadget, shot
end

local function assertGuidanceStops(ttl)
	local gadget, shot = loadGadget("surface")
	gadget:GameFrame(1)
	assert.is_true(shot.velocityY > -2)

	shot.velocityY, shot.ttl = -2, ttl
	gadget:GameFrame(2)
	assert.equals(-2, shot.velocityY)
	-- Retiring the Lua state also prevents a later update with this ID from steering it.
	shot.ttl = 10
	gadget:GameFrame(3)
	assert.equals(-2, shot.velocityY)
end

local function assertShoreProtection(groundTarget)
	local gadget, shot = loadGadget("surface", true)
	shot.height, shot.velocityY, shot.targetHeight, shot.groundTarget = -3, 0, -30, groundTarget
	gadget:GameFrame(1)
	assert.equals(0, shot.velocityY)

	shot.height, shot.velocityY = -1, 5
	gadget:GameFrame(2)
	assert.is_true(shot.height + shot.velocityY <= 2.000001)

	shot.height, shot.velocityY = 3, 5
	gadget:GameFrame(3)
	assert.is_true(shot.height + shot.velocityY <= 0)
end

describe("torpedo guidance", function()
	it("releases expired projectiles to the engine", function()
		assertGuidanceStops(0)
		assertGuidanceStops(-1)
	end)

	it("retires guidance when projectile TTL is unavailable", function()
		assertGuidanceStops(nil)
	end)

	it("hands a level entry near the waterline to surface guidance", function()
		local gadget, shot = loadGadget("water_entry")
		shot.height, shot.velocityY = -1, 0
		gadget:GameFrame(1)
		gadget:GameFrame(2)
		assert.is_true(shot.velocityY < 0)
	end)

	it("keeps shore protection while tracking a submerged unit", function()
		assertShoreProtection(false)
	end)

	it("keeps shore protection while tracking a ground point", function()
		assertShoreProtection(true)
	end)
end)
