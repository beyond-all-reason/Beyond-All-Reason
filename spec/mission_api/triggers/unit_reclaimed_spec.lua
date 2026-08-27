require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time,
-- Game.envDamageTypes from the harness, and UnitDefs inside its handler.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

_G.UnitDefs = { [1] = { name = "armrad" }, [2] = { name = "armsolar" } }

local unitReclaimed = VFS.Include("luarules/mission_api/triggers/unit_reclaimed.lua")
local onUnitDestroyed = unitReclaimed.callins.UnitDestroyed

describe("mission_api.triggers.unit_reclaimed", function()
	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			ActivateTrigger = function()
				fired = fired + 1
			end,
			DoesUnitHaveName = function()
				return true
			end,
		}
		return context, function()
			return fired
		end
	end

	local triggerID = "t"

	-- unitID 100 is the reclaimee, builderID 50 the reclaimer the engine passes as the attacker
	local function destroyed(trigger, context, unitDefID, unitTeam, weaponDefID, opts)
		opts = opts or {}
		weaponDefID = weaponDefID or Game.envDamageTypes.Reclaimed
		GG["MissionAPI"].reclaimingUnits = opts.reclaimingUnits
		onUnitDestroyed(trigger, triggerID, context, 100, unitDefID, unitTeam, 50, 10, 0, weaponDefID)
		GG["MissionAPI"].reclaimingUnits = nil
	end

	it("declares its type and parameters", function()
		assert.are.equal("UnitReclaimed", unitReclaimed.type)
		local names = {}
		for _, parameter in ipairs(unitReclaimed.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.ignoreMissionActions)
		assert.are.same({ "unitName", "unitDefName" }, unitReclaimed.parameters.requiresOneOf)
	end)

	it("fires when a unit is reclaimed", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = "armrad", teamID = 0 }), context, 1, 0)
		assert.are.equal(1, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = "armrad" }), context, 2, 0) -- unitDefID 2 = armsolar
		assert.are.equal(0, fired())
	end)

	it("filters by teamID, which is the reclaimee's team and not the reclaimer's", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = "armrad", teamID = 9 }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		destroyed(trigger({ unitName = "doomedRadar" }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a unit that was shot down", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = "armrad" }), context, 1, 0, 42) -- a real weaponDefID
		assert.are.equal(0, fired())
	end)

	it("fires on a mission reclaim when ignoreMissionActions is false", function()
		local context, fired = newContext()
		destroyed(
			trigger({ unitDefName = "armrad", ignoreMissionActions = false }),
			context,
			1,
			0,
			Game.envDamageTypes.KilledByLua,
			{ reclaimingUnits = true }
		)
		assert.are.equal(1, fired())
	end)

	it("filters mission reclaims by default", function()
		local context, fired = newContext()
		destroyed(
			trigger({ unitDefName = "armrad" }),
			context,
			1,
			0,
			Game.envDamageTypes.KilledByLua,
			{ reclaimingUnits = true }
		)
		assert.are.equal(0, fired())
	end)

	-- DespawnUnits calls Spring.DestroyUnit exactly as ReclaimUnits does, minus the fence.
	it("does not fire for an unfenced Lua kill, such as DespawnUnits", function()
		local context, fired = newContext()
		destroyed(
			trigger({ unitDefName = "armrad", ignoreMissionActions = false }),
			context,
			1,
			0,
			Game.envDamageTypes.KilledByLua
		)
		assert.are.equal(0, fired())
	end)

	it("does not fire for the other environmental damage types", function()
		local context, fired = newContext()
		for _, damageType in ipairs({ "Killed", "SelfD", "KilledByLua", "Crushed", "ConstructionDecay" }) do
			local weaponDefID = Game.envDamageTypes[damageType]
			assert.is_number(weaponDefID, damageType) -- a missing key would pass this test for the wrong reason
			destroyed(trigger({ unitDefName = "armrad" }), context, 1, 0, weaponDefID)
		end
		assert.are.equal(0, fired())
	end)
end)
