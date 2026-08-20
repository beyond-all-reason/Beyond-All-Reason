require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time (so, here)
-- and then Spring.GetUnitIsBeingBuilt / UnitDefs inside its handler.
-- The builder is resolved inside the handler by the gadget via context.IsBuildFrameOwner.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armsolar' }, [2] = { name = 'armwin' } }

local constructionCanceled = VFS.Include('luarules/mission_api/triggers/construction_canceled.lua')
local onUnitDestroyed = constructionCanceled.callins.UnitDestroyed
local onUnitTaken = constructionCanceled.callins.UnitTaken

describe("mission_api.triggers.construction_canceled", function()
	before_each(function()
		-- Default: the destroyed unit was still under construction (a nanoframe).
		Spring.GetUnitIsBeingBuilt = function() return true end
	end)

	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			ActivateTrigger = function() fired = fired + 1 end,
			DoesUnitHaveName = function() return true end,
			IsBuildFrameOwner = function() return true end,
			InFactory = function() return false end,
		}
		return context, function() return fired end
	end

	local triggerID = 't'

	local function destroyed(trigger, context, unitDefID, unitTeam)
		onUnitDestroyed(trigger, triggerID, context, 100, unitDefID, unitTeam)
	end

	local function taken(trigger, context, unitDefID, oldTeam, newTeam)
		onUnitTaken(trigger, triggerID, context, 100, unitDefID, oldTeam, newTeam)
	end

	it("declares its type and parameters", function()
		assert.are.equal('ConstructionCanceled', constructionCanceled.type)
		local names = {}
		for _, parameter in ipairs(constructionCanceled.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.builderName)
		assert.is_true(names.builderDefName)
		assert.are.same({ 'unitName', 'unitDefName' }, constructionCanceled.parameters.requiresOneOf)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = 'armsolar' }), context, 2, 0) -- unitDefID 2 = armwin
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 9)
		assert.are.equal(0, fired())
	end)

	it("fires when an in-progress unit is destroyed", function()
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 0)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a finished unit that is destroyed", function()
		Spring.GetUnitIsBeingBuilt = function() return false end
		local context, fired = newContext()
		destroyed(trigger({ unitDefName = 'armsolar' }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a unit canceled in production at a factory", function()
		local context, fired = newContext()
		context.InFactory = function() return true end
		destroyed(trigger({ unitDefName = 'armsolar' }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("defers builder filtering to context.IsBuildFrameOwner", function()
		local context, fired = newContext()
		context.IsBuildFrameOwner = function() return false end
		destroyed(trigger({ unitDefName = 'armsolar', builderDefName = 'armck' }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("fires for a nanoframe taken by an enemy team, for the team it was taken from", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 0, 9)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a nanoframe given to an allied team (construction continues)", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 0, 2)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a finished unit that is taken", function()
		Spring.GetUnitIsBeingBuilt = function() return false end
		local context, fired = newContext()
		taken(trigger({ unitDefName = 'armsolar' }), context, 1, 0, 9)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a buildee taken in a factory", function()
		local context, fired = newContext()
		context.InFactory = function() return true end
		taken(trigger({ unitDefName = 'armsolar' }), context, 1, 0, 9)
		assert.are.equal(0, fired())
	end)
end)
