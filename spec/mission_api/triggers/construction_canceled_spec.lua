require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time (so, here)
-- and then Spring.GetUnitIsBeingBuilt / UnitDefs inside its handler.
-- The builder is resolved inside the handler by the gadget via context.IsBuildFrameOwner.
Builders.MissionApi.new():Install()

local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armsolar" },
	[2] = { name = "armwin" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local constructionCanceled = VFS.Include("luarules/mission_api/triggers/construction_canceled.lua")
local onMetaUnitRemoved = constructionCanceled.callins.MetaUnitRemoved

describe("mission_api.triggers.construction_canceled", function()
	before_each(function()
		-- Default: the destroyed unit was still under construction (a nanoframe).
		Spring.GetUnitIsBeingBuilt = function()
			return true
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

	local function destroyed(trigger, context, unitDefID, unitTeam)
		onMetaUnitRemoved(trigger, triggerID, context, 100, unitDefID, unitTeam)
	end

	local function taken(trigger, context, unitDefID, oldTeam)
		onMetaUnitRemoved(trigger, triggerID, context, 100, unitDefID, oldTeam)
	end

	it("declares its type and parameters", function()
		assert.are.equal("ConstructionCanceled", constructionCanceled.type)
		local names = {}
		for _, parameter in ipairs(constructionCanceled.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.are.same({ "unitName", "unitDefName" }, constructionCanceled.parameters.requiresOneOf)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = "armsolar" }), context, 2, 0) -- unitDefID 2 = armwin
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = "armsolar", teamID = 0 }), context, 1, 9)
		assert.are.equal(0, fired())
	end)

	it("fires when an in-progress unit is destroyed", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = "armsolar", teamID = 0 }), context, 1, 0)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a finished unit that is destroyed", function()
		Spring.GetUnitIsBeingBuilt = function()
			return false
		end
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = "armsolar" }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a unit canceled in production at a factory", function()
		local context, fired = newContext()
		context.InFactory = function()
			return true
		end
		destroyed(trigger({ unitDefName = "armsolar" }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("fires for a nanoframe taken by an enemy team, for the team it was taken from", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = "armsolar", teamID = 0 }), context, 1, 0)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a finished unit that is taken", function()
		Spring.GetUnitIsBeingBuilt = function()
			return false
		end
		local context, fired = newContext()
		taken(trigger({ unitDefName = "armsolar" }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a buildee taken in a factory", function()
		local context, fired = newContext()
		context.InFactory = function()
			return true
		end
		taken(trigger({ unitDefName = "armsolar" }), context, 1, 0)
		assert.are.equal(0, fired())
	end)
end)
