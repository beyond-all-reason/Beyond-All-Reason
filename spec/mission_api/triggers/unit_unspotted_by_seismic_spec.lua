require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- UnitDefs / Spring.GetUnitTeam inside its handlers.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armpw' }, [2] = { name = 'corfast' } }

local unitUnspottedBySeismic = VFS.Include('mission_api/triggers/unit_unspotted_by_seismic')
local onSeismicPing = unitUnspottedBySeismic.callins.UnitSeismicPing
local onSeismicInterval = unitUnspottedBySeismic.callins.SeismicInterval -- an artificial callin

-- Mirror constants from seismic_contacts.lua. The update interval is in api_missions_trigger.lua.
local INTERVALS_TO_FULL_SCORE = 8 -- Movement while in detection range builds up higher detection.
local INTERVALS_TO_FALLOFF = 16 -- Silence (motionless, out of range) draings the detection score.
local INTERVALS_TO_DWELL = 8 -- A contact is held this long before any falloff whatever its score.

describe("mission_api.triggers.unit_unspotted_by_seismic", function()
	-- Contact scoring lives in the seismic_contacts module, keyed by triggerID, so
	-- each test takes a fresh ID rather than sharing state with the one before it.
	local triggerID
	local triggerCount = 0

	before_each(function()
		triggerCount = triggerCount + 1
		triggerID = 'unspotted-' .. triggerCount -- required to be unique
		Spring.GetUnitTeam = function(_unitID) return 3 end
		Spring.GetUnitIsDead = function(_unitID) return false end
		Spring.GetUnitDefID = function(_unitID) return 1 end -- read back at falloff, not stored
	end)

	local function trigger(parameters, settings)
		return { parameters = parameters or {}, settings = settings or {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			DoesUnitHaveName = function() return true end,
			ActivateTrigger = function() fired = fired + 1 end,
		}
		return context, function() return fired end
	end

	local function ping(triggerType, context, unitID, unitDefID)
		-- x, y, z, and signature strength are unused
		-- spottingAllyTeamID is held constant (as 0)
		-- unitDefID defaults to "armpw", for brevity
		onSeismicPing(triggerType, triggerID, context, 0, 0, 0, 1, 0, unitID, unitDefID or 1)
	end

	---Advances one scoring interval, optionally pinging units.
	local function advance(triggerType, context, pingedUnitIDs)
		for _, unitID in ipairs(pingedUnitIDs or {}) do
			ping(triggerType, context, unitID) -- always "armpw"
		end
		onSeismicInterval(triggerType, triggerID, context)
	end

	local function silence(triggerType, context, intervals)
		for _ = 1, intervals do
			advance(triggerType, context)
		end
	end

	local function fullScore(triggerType, context, unitID)
		for _ = 1, INTERVALS_TO_FULL_SCORE do
			advance(triggerType, context, { unitID })
		end
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
		assert.are.same({ 'unitName', 'unitDefName' }, unitUnspottedBySeismic.parameters.requiresOneOf)
	end)

	it("filters non-matching unitNames", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function() return false end -- unit is never named
		local t = trigger({ unitName = 'engineers' })
		advance(t, context, { 100 })
		silence(t, context, INTERVALS_TO_FALLOFF)
		assert.are.equal(0, fired())
	end)

	it("filters non-matching unitDefs", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'corfast' })
		advance(t, context, { 100 })
		silence(t, context, INTERVALS_TO_FALLOFF)
		assert.are.equal(0, fired())
	end)

	it("filters non-matching spottingAllyTeamID", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw', spottingAllyTeamID = 2 })
		advance(t, context, { 100 }) -- pinged by allyTeam 0: does not match
		silence(t, context, INTERVALS_TO_FALLOFF)
		assert.are.equal(0, fired())
	end)

	it("filters non-matching owningTeamID", function()
		local context, fired = newContext()
		Spring.GetUnitTeam = function(_unitID) return 5 end
		local t = trigger({ unitDefName = 'armpw', owningTeamID = 3 })
		advance(t, context, { 100 })
		silence(t, context, INTERVALS_TO_FALLOFF)
		assert.are.equal(0, fired())
	end)

	it("fires once a full score drains away, and not before", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		fullScore(t, context, 100)
		silence(t, context, INTERVALS_TO_FALLOFF - 1)
		assert.are.equal(0, fired())
		silence(t, context, 1)
		assert.are.equal(1, fired())
	end)

	-- A lone ping scores 2 and drains in 2 intervals, but the dwell floor holds the drained
	-- contact to the same 8 intervals as a full one. Otherwise every isolated ping would spend
	-- itself on a complete spotted/unspotted cycle, meaning perfect on/off trigger flapping.
	it("holds a minimal contact for the complete dwell floor", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		advance(t, context, { 100 })
		silence(t, context, INTERVALS_TO_DWELL - 1)
		assert.are.equal(0, fired())
		silence(t, context, 1)
		assert.are.equal(1, fired())
	end)

	it("fires only once for a unit that stays quiet", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		fullScore(t, context, 100)
		silence(t, context, INTERVALS_TO_FALLOFF + 10)
		assert.are.equal(1, fired())
	end)

	-- An exploit or exploit-adjacent behavior allows moving in short bursts between SlowUpdates
	-- to avoid detection (at all) and dodging the event from UnitSeismicPing. We don't want to
	-- call that unit "unspotted" because it would rearm two symmetric Spotted/Unspotted triggers.
	it("does not fire for a unit pinging every other interval", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		for _ = 1, 50 do
			advance(t, context, { 100 })
			advance(t, context)
		end
		assert.are.equal(0, fired())
	end)

	-- One in three is exactly the break-even rate, so the score neither climbs nor decays.
	it("does not fire for a unit pinging every third interval", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		fullScore(t, context, 100)
		for _ = 1, 50 do
			advance(t, context, { 100 })
			advance(t, context)
			advance(t, context)
		end
		assert.are.equal(0, fired())
	end)

	-- Below the floor, the score drifts down. Sparse pings delay falloff but don't prevent it.
	it("fires for a unit pinging every fourth interval", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		fullScore(t, context, 100)
		for _ = 1, 50 do
			advance(t, context, { 100 })
			advance(t, context)
			advance(t, context)
			advance(t, context)
		end
		assert.is_true(fired() >= 1) -- We do not care exactly when or how many times.
	end)

	it("re-arms after a falloff, and fires again on the next one", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		advance(t, context, { 100 })
		silence(t, context, INTERVALS_TO_DWELL)
		assert.are.equal(1, fired())
		advance(t, context, { 100 })
		silence(t, context, INTERVALS_TO_DWELL)
		assert.are.equal(2, fired())
	end)

	it("tracks each unit's score independently", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		advance(t, context, { 100 })
		advance(t, context, { 101 }) -- unit 101 starts an interval later
		silence(t, context, INTERVALS_TO_DWELL - 1) -- unit 100 is up, 101 is not
		assert.are.equal(1, fired())
		silence(t, context, 1)
		assert.are.equal(2, fired())
	end)

	-- Unit deadness was hard to figure out for this one. Changing it requires care.
	it("skips firing for a unit that is dead when its contact falls off", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		advance(t, context, { 100 })
		Spring.GetUnitIsDead = function(_unitID) return true end
		silence(t, context, INTERVALS_TO_DWELL)
		assert.are.equal(0, fired())
	end)

	it("fires for a spottingAllyTeamID-filtered trigger at falloff", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw', spottingAllyTeamID = 0 })
		advance(t, context, { 100 }) -- pinged by allyTeam 0: matches and is recorded
		silence(t, context, INTERVALS_TO_DWELL)
		assert.are.equal(1, fired())
	end)

	it("skips firing for a unit that left its owningTeamID before falloff", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw', owningTeamID = 3 }) -- team 3 required
		advance(t, context, { 100 }) -- recorded on team 3
		Spring.GetUnitTeam = function(_unitID) return 5 end -- transferred to team 5
		silence(t, context, INTERVALS_TO_DWELL)
		assert.are.equal(0, fired())
	end)

	it("skips firing for a unit that lost its required name before falloff", function()
		local context, fired = newContext()
		local t = trigger({ unitName = 'engineers' }) -- 'engineers' required
		advance(t, context, { 100 }) -- recorded in 'engineers'
		context.DoesUnitHaveName = function() return false end -- unnamed
		silence(t, context, INTERVALS_TO_DWELL)
		assert.are.equal(0, fired())
	end)

	-- There is no ping to say which allyTeam heard an event after falloff.
	it("does not recheck spottingAllyTeamID at falloff", function()
		local context, fired = newContext()
		Spring.GetUnitAllyTeam = nil -- explodes when called
		local t = trigger({ unitDefName = 'armpw', spottingAllyTeamID = 0 })
		advance(t, context, { 100 })
		silence(t, context, INTERVALS_TO_DWELL)
		assert.are.equal(1, fired())
	end)

	-- The trigger uses a sampling method. Pings within one interval are one "sample".
	-- Separate allyTeam detections and re-detections can make this harder to track.
	it("scores an interval once no matter how many pings it held", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		for _ = 1, 10 do
			ping(t, context, 100)
		end
		advance(t, context)
		silence(t, context, INTERVALS_TO_DWELL - 1)
		assert.are.equal(0, fired())
		silence(t, context, 1)
		assert.are.equal(1, fired())
	end)
end)
