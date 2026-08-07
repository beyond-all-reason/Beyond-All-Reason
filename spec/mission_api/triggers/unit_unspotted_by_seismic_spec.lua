require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- UnitDefs / Spring.GetUnitTeam / Spring.GetGameFrame inside its handlers.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armpw' }, [2] = { name = 'corfast' } }

local unitUnspottedBySeismic = VFS.Include('mission_api/triggers/unit_unspotted_by_seismic')
local onSeismicPing = unitUnspottedBySeismic.callins.UnitSeismicPing
local onGameFrame = unitUnspottedBySeismic.callins.GameFrame
local onDestroyed = unitUnspottedBySeismic.callins.UnitDestroyed

local SEISMIC_INTERVAL_FRAMES = 15 -- default timeout 1s = 30 frames = 2 intervals

describe("mission_api.triggers.unit_unspotted_by_seismic", function()
	local currentFrame = 0

	before_each(function()
		currentFrame = 0
		Spring.GetGameFrame = function() return currentFrame end
		Spring.GetUnitTeam = function(_unitID) return 3 end
		Spring.GetUnitIsDead = function(_unitID) return false end
	end)

	local function trigger(parameters, settings)
		return { parameters = parameters or {}, settings = settings or {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			DoesUnitHaveName = function() return true end,
			ActivateTrigger = function() fired = fired + 1 end,
			SeismicContacts = {},
		}
		return context, function() return fired end
	end

	local triggerID = 't'

	local function ping(triggerType, context, unitID, unitDefID)
		-- x, y, z, and signature strength are unused
		-- spottingAllyTeamID is held constant (as 0)
		onSeismicPing(triggerType, triggerID, context, 0, 0, 0, 1, 0, unitID, unitDefID)
	end

	local function tick(triggerType, context, frameNumber)
		currentFrame = frameNumber
		onGameFrame(triggerType, triggerID, context, frameNumber)
	end

	it("declares its type and parameters", function()
		assert.are.equal('UnitUnspottedBySeismic', unitUnspottedBySeismic.type)
		local names = {}
		for _, parameter in ipairs(unitUnspottedBySeismic.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.owningTeamID)
		assert.is_true(names.spottingAllyTeamID)
		assert.is_true(names.timeout)
		assert.are.same({ 'unitName', 'unitDefName' }, unitUnspottedBySeismic.parameters.requiresOneOf)
	end)

	it("filters non-matching unitNames", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function() return false end -- unit is never named
		local t = trigger({ unitName = 'engineers' })
		ping(t, context, 100, 1)
		tick(t, context, 5 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
	end)

	it("filters non-matching unitDefs", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'corfast' })
		ping(t, context, 100, 1)
		tick(t, context, 5 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
	end)

	it("filters non-matching spottingAllyTeamID", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw', spottingAllyTeamID = 2 })
		ping(t, context, 100, 1) -- pinged by allyTeam 0: does not match
		tick(t, context, 5 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
	end)

	it("filters non-matching owningTeamID", function()
		local context, fired = newContext()
		Spring.GetUnitTeam = function(_unitID) return 5 end
		local t = trigger({ unitDefName = 'armpw', owningTeamID = 3 })
		ping(t, context, 100, 1)
		tick(t, context, 5 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
	end)

	it("does not fire before the timeout intervals elapse", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' }) -- defaults to 1.0 sec => 2 intervals
		ping(t, context, 100, 1) -- interval 0
		tick(t, context, 1 * SEISMIC_INTERVAL_FRAMES) -- only 1 interval of silence
		assert.are.equal(0, fired())
	end)

	it("fires after the default timeout (1s = 2 intervals)", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		ping(t, context, 100, 1)
		tick(t, context, 2 * SEISMIC_INTERVAL_FRAMES) -- 2 intervals of silence
		assert.are.equal(1, fired())
	end)

	it("fires only once for a unit that stays quiet", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		ping(t, context, 100, 1)
		tick(t, context, 2 * SEISMIC_INTERVAL_FRAMES)
		tick(t, context, 5 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(1, fired())
	end)

	it("fires on the first empty interval for a zero timeout", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw', timeout = 0 })
		ping(t, context, 100, 1)
		tick(t, context, SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(1, fired())
	end)

	it("fires on the first empty interval for a negative timeout", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw', timeout = -5 })
		ping(t, context, 100, 1)
		tick(t, context, SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(1, fired())
	end)

	it("honours an explicit timeout (2s = 4 intervals)", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw', timeout = 2 })
		ping(t, context, 100, 1)
		tick(t, context, 3 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
		tick(t, context, 4 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(1, fired())
	end)

	it("refreshes the timer while the unit keeps pinging", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		ping(t, context, 100, 1)
		currentFrame = 2 * SEISMIC_INTERVAL_FRAMES
		ping(t, context, 100, 1)
		tick(t, context, 3 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
		tick(t, context, 4 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(1, fired())
	end)

	it("tracks each unit's timeout independently", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		ping(t, context, 100)          -- interval 0
		currentFrame = SEISMIC_INTERVAL_FRAMES
		ping(t, context, 101)          -- interval 1
		tick(t, context, 2 * SEISMIC_INTERVAL_FRAMES) -- unit 100 timed out, 101 not yet
		assert.are.equal(1, fired())
		tick(t, context, 3 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(2, fired())
	end)

	it("skips firing for a unit that is dead when the timeout elapses", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		ping(t, context, 100)
		Spring.GetUnitIsDead = function(_unitID) return true end
		tick(t, context, 2 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
	end)

	it("forgets a destroyed unit without firing", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		ping(t, context, 100)
		onDestroyed(t, triggerID, context, 100)
		tick(t, context, 5 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
	end)

	it("fires for a spottingAllyTeamID-filtered trigger at timeout", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw', spottingAllyTeamID = 0 })
		ping(t, context, 100) -- pinged by allyTeam 0: matches and is recorded
		tick(t, context, 2 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(1, fired())
	end)

	it("skips firing for a unit that left its owningTeamID before timeout", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw', owningTeamID = 3 })
		ping(t, context, 100) -- on team 3: recorded
		Spring.GetUnitTeam = function(_unitID) return 5 end -- transferred away
		tick(t, context, 2 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
	end)

	it("skips firing for a unit that lost its required name before timeout", function()
		local context, fired = newContext()
		local t = trigger({ unitName = 'engineers' })
		ping(t, context, 100) -- named: recorded
		context.DoesUnitHaveName = function() return false end -- unnamed
		tick(t, context, 2 * SEISMIC_INTERVAL_FRAMES)
		assert.are.equal(0, fired())
	end)
end)
