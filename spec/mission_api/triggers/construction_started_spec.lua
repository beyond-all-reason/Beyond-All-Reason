require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- Spring.GetUnitIsBeingBuilt / UnitDefs / Spring.GetUnitDefID inside its handler.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

-- Builder ids double as their own defIDs below, so UnitDefs is keyed by both. Maybe too confusing.
_G.UnitDefs = { [1] = { name = 'armsolar' }, [2] = { name = 'armwin' }, [10] = { name = 'armck' }, [11] = { name = 'corck' } }

local constructionStarted = VFS.Include('luarules/mission_api/triggers/construction_started.lua')
local onUnitCreated = constructionStarted.callins.UnitCreated

describe("mission_api.triggers.construction_started", function()
	before_each(function()
		Spring.GetUnitIsBeingBuilt = function() return true end
		Spring.GetUnitDefID = function(unitID) return unitID end
	end)

	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			ActivateTrigger = function() fired = fired + 1 end,
			DoesUnitHaveName = function() return true end,
		}
		return context, function() return fired end
	end

	local triggerID = 't'

	-- unitID 100 is the nanoframe
	-- builderID carries the builder's defID anyway so this is double-used; see GetUnitDefID above; maybe too confusing.
	local function created(trigger, context, unitDefID, unitTeam, builderID)
		onUnitCreated(trigger, triggerID, context, 100, unitDefID, unitTeam, builderID)
	end

	it("declares its type and parameters", function()
		assert.are.equal('ConstructionStarted', constructionStarted.type)
		local names = {}
		for _, parameter in ipairs(constructionStarted.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.builderName)
		assert.is_true(names.builderDefName)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = 'armsolar' }), context, 2, 0, 10) -- unitDefID 2 = armwin
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 9, 10)
		assert.are.equal(0, fired())
	end)

	it("filters by builderDefName", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = 'armsolar', builderDefName = 'corck' }), context, 1, 0, 10) -- builder 10 = armck
		assert.are.equal(0, fired())
		created(trigger({ unitDefName = 'armsolar', builderDefName = 'armck' }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("filters by builderName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function() return false end
		created(trigger({ unitDefName = 'armsolar', builderName = 'engineer' }), context, 1, 0, 10)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a unit that is not being built", function()
		Spring.GetUnitIsBeingBuilt = function() return false end
		local context, fired = newContext()
		created(trigger({ unitDefName = 'armsolar' }), context, 1, 0, 10)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching construction", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 0, 10)
		assert.are.equal(1, fired())
	end)

	it("does not fire a builder-filtered trigger when there is no builder", function()
		local context, fired = newContext()
		created(trigger({ unitDefName = 'armsolar', builderDefName = 'armck' }), context, 1, 0, nil)
		assert.are.equal(0, fired())
	end)
end)
