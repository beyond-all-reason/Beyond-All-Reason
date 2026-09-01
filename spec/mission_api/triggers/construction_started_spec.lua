require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- Spring.GetUnitIsBeingBuilt / UnitDefs / Spring.GetUnitDefID inside its handler.
Builders.MissionApi.new():Install()

-- Builder ids double as their own defIDs below, so UnitDefs is keyed by both. Maybe too confusing.
local unitDefs = Builders.UnitDefs.new():WithUnitDefs({
	[1] = { name = "armsolar" },
	[2] = { name = "armwin" },
	[10] = { name = "armck" },
	[11] = { name = "corck" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local constructionStarted = VFS.Include("luarules/mission_api/triggers/construction_started.lua")
local onUnitCreated = constructionStarted.callins.UnitCreated
local onBuildAssisted = constructionStarted.callins.BuildAssisted -- Custom callin from the trigger gadget.

describe("mission_api.triggers.construction_started", function()
	before_each(function()
		Spring.GetUnitIsBeingBuilt = function()
			return true
		end
		Spring.GetUnitDefID = function(unitID)
			return unitID
		end
	end)

	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	-- The gadget's build claims live across the mission; each built context carries its own,
	-- and its ActivateTrigger reports the success that claiming depends on.
	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	-- unitID 100 is the nanoframe
	-- builderID carries the builder's defID anyway so this is double-used; see GetUnitDefID above; maybe too confusing.
	local function created(trigger, context, unitDefID, unitTeam, builderID)
		onUnitCreated(trigger, triggerID, context, 100, unitDefID, unitTeam, builderID)
	end

	-- goes through AllowUnitCreation => is rejected but becomes a build-assist.
	local function assisted(trigger, context, unitDefID, unitTeam, builderID)
		onBuildAssisted(trigger, triggerID, context, 100, unitDefID, unitTeam, builderID)
	end

	it("declares its type and parameters", function()
		assert.are.equal("ConstructionStarted", constructionStarted.type)
		local names = {}
		for _, parameter in ipairs(constructionStarted.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.builderName)
		assert.is_true(names.builderDefName)
	end)

	it("declares both a build frame and a build-assist call-in", function()
		assert.is_function(onUnitCreated)
		assert.is_function(onBuildAssisted)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "armsolar" }), context, 2, 0, 10) -- unitDefID 2 = armwin
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "armsolar", teamID = 0 }), context, 1, 9, 10)
		assert.are.equal(0, fired())
	end)

	it("filters by builderDefName", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "armsolar", builderDefName = "corck" }), context, 1, 0, 10) -- builder 10 = armck
		assert.are.equal(0, fired())
		created(trigger({ unitDefName = "armsolar", builderDefName = "armck" }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("filters by builderName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		created(trigger({ unitDefName = "armsolar", builderName = "engineer" }), context, 1, 0, 10)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a unit that is not being built", function()
		Spring.GetUnitIsBeingBuilt = function()
			return false
		end
		local context, fired = newContext()
		created(trigger({ unitDefName = "armsolar" }), context, 1, 0, 10)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching construction", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "armsolar", teamID = 0 }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("does not fire a builder-filtered trigger when there is no builder", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "armsolar", builderDefName = "armck" }), context, 1, 0, nil)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching build-assist", function()
		local context, fired = newContext()
		assisted(trigger({ unitDefName = "armsolar", teamID = 0 }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("filters a build-assist by its assisting builder", function()
		local context, fired = newContext()
		assisted(trigger({ unitDefName = "armsolar", builderDefName = "corck" }), context, 1, 0, 10) -- builder 10 = armck
		assert.are.equal(0, fired())
		assisted(trigger({ unitDefName = "armsolar", builderDefName = "armck" }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("fires for an assist when the build frame itself did not match", function()
		local context, fired = newContext()
		local watchTheCorck = trigger({ unitDefName = "armsolar", builderDefName = "corck" })
		created(watchTheCorck, context, 1, 0, 10) -- placed by armck, so no match and no claim
		assert.are.equal(0, fired())
		assisted(watchTheCorck, context, 1, 0, 11) -- joined by corck
		assert.are.equal(1, fired())
	end)

	it("does not fire again for a buildee it already started on", function()
		local context, fired = newContext()
		local watchTheSolar = trigger({ unitDefName = "armsolar" })
		created(watchTheSolar, context, 1, 0, 10)
		assisted(watchTheSolar, context, 1, 0, 11)
		assert.are.equal(1, fired())
	end)

	it("fires once for a buildee no matter how many builders join it", function()
		local context, fired = newContext()
		local watchTheSolar = trigger({ unitDefName = "armsolar" })
		assisted(watchTheSolar, context, 1, 0, 10)
		assisted(watchTheSolar, context, 1, 0, 11)
		assert.are.equal(1, fired())
	end)

	it("does not claim a buildee when the activation is refused", function()
		local context, fired = newContext()
		local watchTheSolar = trigger({ unitDefName = "armsolar" })
		local activateTrigger = context.ActivateTrigger

		context.ActivateTrigger = function()
			return false
		end
		created(watchTheSolar, context, 1, 0, 10)
		assert.are.equal(0, fired())

		context.ActivateTrigger = activateTrigger
		assisted(watchTheSolar, context, 1, 0, 11)
		assert.are.equal(1, fired())
	end)
end)
