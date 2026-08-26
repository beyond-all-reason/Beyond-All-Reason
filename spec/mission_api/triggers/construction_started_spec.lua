require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- Spring.GetUnitIsBeingBuilt / UnitDefs / Spring.GetUnitDefID inside its handler.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].Teams = { thePlayerTeam = 0, theEnemyTeam = 1 }

-- Builder ids double as their own defIDs below, so UnitDefs is keyed by both. Maybe too confusing.
_G.UnitDefs =
	{ [1] = { name = "armsolar" }, [2] = { name = "armwin" }, [10] = { name = "armck" }, [11] = { name = "corck" } }

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
		return { parameters = parameters or {}, settings = {} }
	end

	-- Build claims outlive one context. Ordinarily they live across the mission/until completed.
	local function newContext()
		local fired = 0
		local claims = {}
		local context = {
			-- Unusual for most triggers: We need the trigger return value.
			-- Actually, I wonder if this is a gap in our testing. We'll know soon.
			ActivateTrigger = function()
				fired = fired + 1
				return true
			end,
			DoesUnitHaveName = function()
				return true
			end,
			HasConstructionStarted = function(buildeeID, triggerID)
				return claims[buildeeID] and claims[buildeeID][triggerID]
			end,
			ClaimConstructionStart = function(buildeeID, triggerID)
				claims[buildeeID] = claims[buildeeID] or {}
				claims[buildeeID][triggerID] = true
			end,
		}
		return context, function()
			return fired
		end
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
		assert.is_true(names.teamName)
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

	it("filters by teamName", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = 'armsolar', teamName = 'thePlayerTeam' }), context, 1, 9, 10)
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
		created(trigger({ unitDefName = 'armsolar', teamName = 'thePlayerTeam' }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("does not fire a builder-filtered trigger when there is no builder", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = "armsolar", builderDefName = "armck" }), context, 1, 0, nil)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching build-assist", function()
		local context, fired = newContext()
		assisted(trigger({ unitDefName = 'armsolar', teamName = 'thePlayerTeam' }), context, 1, 0, 10)
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
