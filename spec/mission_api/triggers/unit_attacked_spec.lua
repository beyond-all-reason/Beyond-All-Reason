require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes and Game.envDamageTypes at load time
-- (so, here), and Spring / UnitDefs inside its handler.
Builders.MissionApi.new():Install()

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armpw" },
	[2] = { name = "corak" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local unitAttacked = VFS.Include("luarules/mission_api/triggers/unit_attacked.lua")
local onUnitDamaged = unitAttacked.callins.UnitDamaged

describe("mission_api.triggers.unit_attacked", function()
	before_each(function()
		-- Teams 0 and 1 are enemies; team 2 is allied with team 0.
		Spring.AreTeamsAllied = function(team1ID, team2ID)
			if team1ID == team2ID then
				return true
			end
			return (team1ID == 0 and team2ID == 2) or (team1ID == 2 and team2ID == 0)
		end
	end)

	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	-- unitID 100 takes the hit. A live attacker is unitID 50 (a corak) on `attackerTeam`. The engine
	-- reports a dead attacker with no attacker info at all; the gadget then recovers `attackerTeam`
	-- from the projectile when there is one, which `attackerDead` models.
	local function damaged(trigger, context, hit)
		local attackerID, attackerDefID
		if hit.attackerTeam and not hit.attackerDead then
			attackerID, attackerDefID = 50, 2
		end
		onUnitDamaged(
			trigger,
			triggerID,
			context,
			100,
			hit.unitDefID,
			hit.unitTeam,
			hit.damage,
			hit.paralyzer or false,
			hit.weaponDefID,
			-1,
			attackerID,
			attackerDefID,
			hit.attackerTeam
		)
	end

	local WEAPON = 7 -- Real weaponDefIDs start at 0.

	it("declares its type and parameters", function()
		assert.are.equal("UnitAttacked", unitAttacked.type)
		local names = {}
		for _, parameter in ipairs(unitAttacked.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.are.same({ "unitName", "unitDefName" }, unitAttacked.parameters.requiresOneOf)
	end)

	it("fires when an enemy weapon hits a matching unit", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw", teamID = 0 }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			weaponDefID = WEAPON,
			attackerTeam = 1,
		})
		assert.are.equal(1, fired())
	end)

	it("fires once per hit", function()
		local context, fired = newContext()
		for _ = 1, 3 do
			damaged(trigger({ unitDefName = "armpw" }), context, {
				unitDefID = 1,
				unitTeam = 0,
				damage = 50,
				weaponDefID = WEAPON,
				attackerTeam = 1,
			})
		end
		assert.are.equal(3, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		damaged(trigger({ unitName = "target" }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			weaponDefID = WEAPON,
			attackerTeam = 1,
		})
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "corak" }), context, {
			unitDefID = 1, -- armpw
			unitTeam = 0,
			damage = 50,
			weaponDefID = WEAPON,
			attackerTeam = 1,
		})
		assert.are.equal(0, fired())
	end)

	it("filters by teamID, which is the attacked unit's team", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw", teamID = 1 }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			weaponDefID = WEAPON,
			attackerTeam = 1,
		})
		assert.are.equal(0, fired())
	end)

	it("counts paralyze damage as an attack", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw" }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			paralyzer = true,
			weaponDefID = WEAPON,
			attackerTeam = 1,
		})
		assert.are.equal(1, fired())
	end)

	it("ignores hits that deal no damage", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw" }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 0,
			weaponDefID = WEAPON,
			attackerTeam = 1,
		})
		assert.are.equal(0, fired())
	end)

	it("ignores damage from the unit's own team", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw" }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			weaponDefID = WEAPON,
			attackerTeam = 0,
		})
		assert.are.equal(0, fired())
	end)

	it("ignores damage from an allied team", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw" }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			weaponDefID = WEAPON,
			attackerTeam = 2,
		})
		assert.are.equal(0, fired())
	end)

	it("fires for a dead attacker's projectile once its team is recovered", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw" }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			weaponDefID = WEAPON,
			attackerTeam = 1,
			attackerDead = true,
		})
		assert.are.equal(1, fired())
	end)

	-- Death and self-destruct explosions use real weapons but arrive with no attacker and no projectile.
	it("ignores weapon damage with no team to blame", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw" }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			weaponDefID = WEAPON,
			attackerTeam = nil,
		})
		assert.are.equal(0, fired())
	end)

	it("ignores the engine's environmental damage types", function()
		local context, fired = newContext()
		local environmental = {
			Game.envDamageTypes.Debris,
			Game.envDamageTypes.GroundCollision,
			Game.envDamageTypes.ObjectCollision,
			Game.envDamageTypes.Fire,
			Game.envDamageTypes.Water,
			Game.envDamageTypes.Killed,
			Game.envDamageTypes.AircraftCrashed,
			Game.envDamageTypes.Kamikaze,
			Game.envDamageTypes.SelfD,
			Game.envDamageTypes.KilledByLua,
		}
		for _, weaponDefID in ipairs(environmental) do
			damaged(trigger({ unitDefName = "armpw" }), context, {
				unitDefID = 1,
				unitTeam = 0,
				damage = 50,
				weaponDefID = weaponDefID,
				attackerTeam = 1,
			})
		end
		assert.are.equal(0, fired())
	end)

	it("counts being crushed as an attack", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw" }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			weaponDefID = Game.envDamageTypes.Crushed,
			attackerTeam = 1,
		})
		assert.are.equal(1, fired())
	end)

	-- The game registers scripted damage types (timed areas, ...) below the engine's lowest index.
	it("counts the game's scripted damage types as attacks", function()
		local context, fired = newContext()
		damaged(trigger({ unitDefName = "armpw" }), context, {
			unitDefID = 1,
			unitTeam = 0,
			damage = 50,
			weaponDefID = Game.envDamageTypes.KilledByLua - 1,
			attackerTeam = 1,
		})
		assert.are.equal(1, fired())
	end)
end)
