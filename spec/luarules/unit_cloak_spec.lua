---@diagnostic disable: undefined-field, redundant-parameter

describe("cloak delay after firing", function()
	local gadget, watches, env

	local function loadGadget(hasShotAPI)
		watches = {}
		local defs = {
			{
				canCloak = true,
				cloakCost = 10,
				cloakCostMoving = 20,
				decloakOnFire = true,
				weapons = { { weaponDef = 11 }, { weaponDef = 12 } },
			},
			{
				canCloak = true,
				cloakCost = 10,
				cloakCostMoving = 20,
				decloakOnFire = false,
				weapons = { { weaponDef = 11 }, { weaponDef = 13 } },
			},
			{ canCloak = false, decloakOnFire = true, weapons = { { weaponDef = 14 } } },
		}
		gadget = {}
		env = setmetatable({
			gadget = gadget,
			gadgetHandler = {
				IsSyncedCode = function()
					return true
				end,
				RegisterAllowCommand = function() end,
			},
			include = function() end,
			CMD = { CLOAK = 95 },
			CMDTYPE = { ICON_MODE = 5 },
			CMD_WANT_CLOAK = 123,
			GG = {},
			UnitDefs = defs,
			Script = {},
			Spring = {
				GetAllUnits = function()
					return {}
				end,
				GetUnitIsStunned = function()
					return false
				end,
				GetUnitDefID = function(id)
					return id
				end,
				GetUnitRulesParam = function()
					return 0
				end,
				GetUnitVelocity = function()
					return 0, 0, 0, 0
				end,
				UseUnitResource = function()
					return true
				end,
			},
		}, { __index = _G })
		if hasShotAPI then
			env.Script.SetWatchWeaponFired = function(id, enabled)
				watches[id] = enabled
			end
		end
		local chunk = assert(loadfile("luarules/gadgets/unit_cloak.lua"))
		setfenv(chunk, env)
		chunk()
		gadget:Initialize()
	end

	before_each(function()
		loadGadget(true)
	end)

	it("watches only weapons of cloakable units that decloak on fire", function()
		assert.same({ [11] = true, [12] = true }, watches)
	end)

	it("blocks cloaking for 128 frames after a shot with cloak disabled", function()
		gadget:GameFrame(100)
		assert.is_true(gadget:AllowUnitCloak(1))
		gadget:UnitWeaponFired(1, 1, 0, 2)
		assert.is_false(gadget:AllowUnitCloak(1))
		gadget:GameFrame(227)
		assert.is_false(gadget:AllowUnitCloak(1))
		gadget:GameFrame(228)
		assert.is_true(gadget:AllowUnitCloak(1))
	end)

	it("extends the delay from every shot of a burst", function()
		gadget:GameFrame(100)
		gadget:UnitWeaponFired(1, 1, 0, 1)
		gadget:GameFrame(120)
		gadget:UnitWeaponFired(1, 1, 0, 1)
		gadget:GameFrame(228)
		assert.is_false(gadget:AllowUnitCloak(1))
		gadget:GameFrame(248)
		assert.is_true(gadget:AllowUnitCloak(1))
	end)

	it("does not penalize a shared weapon on a unit that fires while cloaked", function()
		gadget:GameFrame(100)
		gadget:UnitWeaponFired(2, 2, 0, 1)
		assert.is_true(gadget:AllowUnitCloak(2))
	end)

	it("preserves delays from other decloak causes", function()
		gadget:GameFrame(100)
		gadget:UnitWeaponFired(1, 1, 0, 1)
		gadget:GameFrame(150)
		gadget:AllowUnitDecloak(1, 99)
		gadget:GameFrame(228)
		assert.is_false(gadget:AllowUnitCloak(1))
		gadget:GameFrame(278)
		assert.is_true(gadget:AllowUnitCloak(1))
	end)

	it("clears the delay before a destroyed unit ID is reused", function()
		gadget:GameFrame(100)
		gadget:UnitWeaponFired(1, 1, 0, 1)
		gadget:UnitDestroyed(1)
		assert.is_true(gadget:AllowUnitCloak(1))
	end)

	it("keeps the existing decloak path available on older engines", function()
		loadGadget(false)
		assert.same({}, watches)
		gadget:GameFrame(100)
		gadget:AllowUnitDecloak(1)
		assert.is_false(gadget:AllowUnitCloak(1))
		gadget:GameFrame(228)
		assert.is_true(gadget:AllowUnitCloak(1))
	end)
end)
