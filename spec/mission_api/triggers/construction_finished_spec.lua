require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time (so, here)
-- and UnitDefs inside its handler. The was-built proof and builder are resolved by the gadget
-- via both context.WasUnderConstruction and context.isBuildFrameOwner. Expensive little piece.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armsolar' }, [2] = { name = 'armwin' } }

local constructionFinished = VFS.Include('luarules/mission_api/triggers/construction_finished.lua')
local onUnitFinished = constructionFinished.callins.UnitFinished

describe("mission_api.triggers.construction_finished", function()
	before_each(function()
		-- Default: Teams are only allied with themselves. SOME TESTS WIDEN THIS.
		Spring.AreTeamsAllied = function(teamA, teamB) return teamA == teamB end
	end)

	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			ActivateTrigger = function() fired = fired + 1 end,
			DoesUnitHaveName = function() return true end,
			isBuildFrameOwner = function() return true end,
			WasUnderConstruction = function() return true end,
		}
		return context, function() return fired end
	end

	local triggerID = 't'

	local function finished(trigger, context, unitDefID, unitTeam)
		onUnitFinished(trigger, triggerID, context, 100, unitDefID, unitTeam)
	end

	it("declares its type and parameters", function()
		assert.are.equal('ConstructionFinished', constructionFinished.type)
		local names = {}
		for _, parameter in ipairs(constructionFinished.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.builderName)
		assert.is_true(names.builderDefName)
		assert.are.same({ 'unitName', 'unitDefName' }, constructionFinished.parameters.requiresOneOf)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		finished(trigger({ unitDefName = 'armsolar' }), context, 2, 0) -- unitDefID 2 = armwin
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function() return false end
		finished(trigger({ unitName = 'powerplant' }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("fires for a matching completed unit", function()
		local context, fired = newContext()
		finished(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 0)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a unit that was never under construction (spawned)", function()
		local context, fired = newContext()
		context.WasUnderConstruction = function() return false end
		finished(trigger({ unitDefName = 'armsolar' }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("does not fire when finished on a team not allied with teamID (stolen away)", function()
		local context, fired = newContext()
		finished(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 9)
		assert.are.equal(0, fired())
	end)

	it("fires when finished on a team allied with teamID (captured onto our side)", function()
		local context, fired = newContext()
		Spring.AreTeamsAllied = function(teamA, teamB)
			return teamA == teamB or (teamA == 0 and teamB == 2) or (teamA == 2 and teamB == 0)
		end
		finished(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 2) -- team 2 allied with 0
		assert.are.equal(1, fired())
	end)

	it("defers builder filtering to context.isBuildFrameOwner", function()
		local context, fired = newContext()
		context.isBuildFrameOwner = function() return false end
		finished(trigger({ unitDefName = 'armsolar', builderDefName = 'armck' }), context, 1, 0)
		assert.are.equal(0, fired())
	end)
end)
