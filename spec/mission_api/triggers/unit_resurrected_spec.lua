require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- Spring.GetUnitWorkerTask / CMD.RESURRECT / Engine.FeatureSupport / Game.maxUnits / UnitDefs inside its handler.
Builders.MissionApi.new():Install()

_G.CMD = _G.CMD or {}
_G.CMD.RESURRECT = 125
_G.CMD.RECLAIM = 90

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armpw" },
	[2] = { name = "corfast" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

_G.Game.maxUnits = _G.Game.maxUnits or 32000

_G.Engine = _G.Engine or {}
_G.Engine.FeatureSupport = _G.Engine.FeatureSupport or {}
_G.Engine.FeatureSupport.noOffsetForFeatureID = true

local unitResurrected = VFS.Include("luarules/mission_api/triggers/unit_resurrected.lua")
local onUnitCreated = unitResurrected.callins.UnitCreated

describe("mission_api.triggers.unit_resurrected", function()
	before_each(function()
		Spring.GetUnitWorkerTask = function()
			return CMD.RESURRECT, 500
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

	-- unitID 100 is the resurrected unit; builderID 10 is the engineer resurrecting it.
	local function created(t, context, unitDefID, unitTeam, builderID)
		onUnitCreated(t, triggerID, context, 100, unitDefID, unitTeam, builderID)
	end

	it("declares its type and parameters", function()
		assert.are.equal("UnitResurrected", unitResurrected.type)
		local names = {}
		for _, parameter in ipairs(unitResurrected.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.featureName)
		assert.are.same({ "featureName", "unitDefName" }, unitResurrected.parameters.requiresOneOf)
	end)

	it("does not fire for a unit created with no builder", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "armpw" }), context, 1, 0, nil)
		assert.are.equal(0, fired())
	end)

	it("does not fire when the builder is not resurrecting", function()
		Spring.GetUnitWorkerTask = function()
			return CMD.RECLAIM, 500
		end
		local context, fired = newContext()
		created(trigger({ unitDefName = "armpw" }), context, 1, 0, 10)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "corfast" }), context, 1, 0, 10) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "armpw", teamID = 5 }), context, 1, 0, 10)
		assert.are.equal(0, fired())
	end)

	it("filters by featureName", function()
		local context, fired = newContext()
		context.DoesFeatureHaveName = function()
			return false
		end
		created(trigger({ featureName = "wreck1" }), context, 1, 0, 10)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching resurrection", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "armpw", teamID = 0 }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("offsets the featureID by Game.maxUnits on engines without native support", function()
		Engine.FeatureSupport.noOffsetForFeatureID = false
		local seenFeatureID
		Spring.GetUnitWorkerTask = function()
			return CMD.RESURRECT, Game.maxUnits + 42
		end
		local context, fired = newContext()
		context.DoesFeatureHaveName = function(featureID)
			seenFeatureID = featureID
			return true
		end
		created(trigger({ featureName = "wreck1" }), context, 1, 0, 10)
		assert.are.equal(42, seenFeatureID)
		assert.are.equal(1, fired())
	end)
end)
