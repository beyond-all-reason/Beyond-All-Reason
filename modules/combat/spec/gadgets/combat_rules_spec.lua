
local realVFS = VFS

local GADGET = "modules/combat/gadgets/combat_rules.lua"

local function newGadget()
	local h = {
		units = {},
		neutral = {},
		paralyze = {},
		updated = {},
		frame = 0,
	}

	local spring = {
		ValidUnitID = function(unitID)
			return h.units[unitID] == true
		end,
		GetUnitNeutral = function(unitID)
			return h.neutral[unitID] == true
		end,
		SetUnitNeutral = function(unitID, value)
			h.neutral[unitID] = value
		end,
		GetUnitHealth = function()
			return 100, 100
		end,
		SetUnitHealth = function(unitID, values)
			h.paralyze[unitID] = values.paralyze
		end,
		GetGameFrame = function()
			return h.frame
		end,
	}

	local env = setmetatable({
		VFS = realVFS,
		Spring = spring,
		GG = {},
		Game = { gameSpeed = 30 },
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			UpdateCallIn = function(_, name)
				h.updated[name] = (h.updated[name] or 0) + 1
			end,
		},
	}, { __index = _G })

	realVFS.Include(GADGET, env)
	assert(type(env.gadget.Initialize) == "function", "the combat_rules gadget did not load")
	h.gadget = env.gadget
	h.gadget:Initialize()
	h.Combat = env.GG.Combat

	---@param unitID integer
	h.spawn = function(unitID, neutral)
		h.units[unitID] = true
		h.neutral[unitID] = neutral == true
		return unitID
	end
	h.preDamaged = function(unitID)
		if h.gadget.UnitPreDamaged == nil then
			return nil
		end
		return h.gadget:UnitPreDamaged(unitID, 100, 0, 1, 1, 2)
	end

	return h
end

describe("combat_rules", function()
	describe("targeting", function()
		it("never joins the AllowWeaponTarget loop", function()
			local h = newGadget()
			assert.is_nil(h.gadget.AllowWeaponTarget)
			h.Combat.Protect(h.spawn(7))
			assert.is_nil(h.gadget.AllowWeaponTarget)
			assert.is_nil(h.updated.AllowWeaponTarget)
		end)

		it("makes a protected unit neutral so attackers stop acquiring it", function()
			local h = newGadget()
			h.spawn(7)
			assert.is_false(h.neutral[7])
			h.Combat.Protect(7)
			assert.is_true(h.neutral[7])
			h.Combat.Unprotect(7)
			assert.is_false(h.neutral[7])
		end)

		it("restores neutrality it did not set", function()
			local h = newGadget()
			h.spawn(7, true)
			h.Combat.Protect(7)
			assert.is_true(h.neutral[7])
			h.Combat.Unprotect(7)
			assert.is_true(h.neutral[7])
		end)

		it("lifts neutrality on the last release, not the first", function()
			local h = newGadget()
			h.spawn(7)
			h.Combat.Protect(7)
			h.Combat.Protect(7)
			h.Combat.Unprotect(7)
			assert.is_true(h.neutral[7])
			assert.is_true(h.Combat.IsProtected(7))
			h.Combat.Unprotect(7)
			assert.is_false(h.neutral[7])
			assert.is_false(h.Combat.IsProtected(7))
		end)
	end)

	describe("the damage floor", function()
		it("applies only while something is protected", function()
			-- Stays installed when the ledger is empty: unhooking from inside a callin
			-- leaves the gadget in the handler's deferred list with a nil method.
			local h = newGadget()
			h.spawn(7)
			assert.is_function(h.gadget.UnitPreDamaged)
			assert.is_nil(h.preDamaged(7))
			h.Combat.Protect(7)
			assert.are.same({ 0, 0 }, { h.preDamaged(7) })
			assert.is_nil(h.preDamaged(8))
			h.Combat.Unprotect(7)
			assert.is_nil(h.preDamaged(7))
		end)

		it("survives one release of two overlapping lifetimes", function()
			local h = newGadget()
			h.spawn(7)
			h.Combat.Protect(7)
			h.Combat.Protect(7)
			h.Combat.Unprotect(7)
			assert.are.same({ 0, 0 }, { h.preDamaged(7) })
		end)

		it("drops with the unit", function()
			local h = newGadget()
			h.spawn(7)
			h.Combat.Protect(7)
			h.gadget:UnitDestroyed(7)
			assert.is_nil(h.preDamaged(7))
			assert.is_false(h.Combat.IsProtected(7))
		end)

		it("forgets a dead unit's neutrality, so a recycled ID cannot inherit it", function()
			local h = newGadget()
			h.spawn(7, true)
			h.Combat.Protect(7)
			h.gadget:UnitDestroyed(7)
			h.units[7] = nil

			h.Combat.Protect(7)
			h.spawn(7)
			h.Combat.Unprotect(7)
			assert.is_false(h.neutral[7])
		end)
	end)

	describe("stun", function()
		it("paralyzes above max health and releases on its frame", function()
			local h = newGadget()
			h.spawn(7)
			h.Combat.Stun(7, 2)
			assert.are.equal(150, h.paralyze[7])
			assert.is_function(h.gadget.GameFrame)

			h.gadget:GameFrame(30)
			assert.are.equal(150, h.paralyze[7])
			h.gadget:GameFrame(60)
			assert.are.equal(0, h.paralyze[7])
		end)

		it("keeps its callin installed once the last stun ends", function()
			local h = newGadget()
			h.spawn(7)
			h.Combat.Stun(7, 2)
			h.gadget:GameFrame(60)
			assert.is_function(h.gadget.GameFrame)
			assert.has_no.errors(function()
				h.gadget:GameFrame(90)
			end)
		end)
	end)
end)
