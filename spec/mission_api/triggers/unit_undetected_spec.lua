require("spec_helper")
require("mission_api.spec_helper")

-- The trigger reads ParameterTypes and DetectionLevels at load time, and detection_levels
-- reads SeismicContacts and the allyTeam layout at its own load. Inside the handler it
-- reads UnitDefs and Spring's unit and LOS state.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].Modules.SeismicContacts = GG['MissionAPI'].Modules.SeismicContacts or {
	IsContact = function() return false end,
}

_G.UnitDefs = { [1] = { name = 'armpw' }, [2] = { name = 'corfast' } }

GG['MissionAPI'].Modules.DetectionLevels = VFS.Include('luarules/mission_api/detection_levels.lua')
local DetectionLevels = GG['MissionAPI'].Modules.DetectionLevels

local unitUndetected = VFS.Include('luarules/mission_api/triggers/unit_undetected.lua')
local onDetectionUpdate = unitUndetected.callins.DetectionUpdate -- an artificial callin
local onDestroyed = unitUndetected.callins.UnitDestroyed

-- LosMask bits, as the engine reports them through Spring.GetUnitLosState(_, _, true).
local INLOS, INRADAR, PREVLOS, CONTRADAR = 1, 2, 4, 8

-- The allyTeam layout bakes into detection_levels at its load above, from the mission_api
-- spec_helper's stubs: two playing allyTeams and Gaia. These names address that layout.
local SENSOR_ALLY, OTHER_ALLY, GAIA_ALLY = 0, 1, 2

describe("mission_api.triggers.unit_undetected", function()
	-- The latch lives in detection_levels, keyed by triggerID, and the spec harness caches
	-- includes, so IDs run forward across the whole file rather than restarting per test.
	local losStatus
	local nextTriggerID, nextUnitID = 0, 2000

	before_each(function()
		losStatus = {}

		Spring.GetUnitLosState = function(unitID, allyTeamID, _raw)
			return losStatus[unitID] and losStatus[unitID][allyTeamID] or 0
		end
		Spring.GetUnitIsDead = function(_unitID) return false end
		Spring.GetUnitDefID = function(_unitID) return 1 end -- 'armpw', read back on an edge
		Spring.GetUnitTeam = function(_unitID) return 3 end
		-- These tests set LOS explicitly per allyTeam. The default owner is an allyTeam that
		-- never senses, so ownership does not mask those setups; tests about the owner's own
		-- vision override this.
		Spring.GetUnitAllyTeam = function(_unitID) return GAIA_ALLY end
	end)

	local function freshTriggerID()
		nextTriggerID = nextTriggerID + 1
		return 'undetected-' .. nextTriggerID
	end

	local function freshUnitID()
		nextUnitID = nextUnitID + 1
		return nextUnitID
	end

	local function trigger(parameters, settings)
		return { parameters = parameters or {}, settings = settings or {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			ActivateTrigger = function() fired = fired + 1 end,
			DoesUnitHaveName = function() return true end,
		}
		return context, function() return fired end
	end

	---Runs one detection sweep over the given units, which is what the gadget raises per frame.
	local function update(triggerType, triggerID, context, unitIDs)
		DetectionLevels.BeginUpdate()
		local dirtyUnits = {}
		for _, unitID in ipairs(unitIDs) do
			dirtyUnits[unitID] = true
		end
		onDetectionUpdate(triggerType, triggerID, context, dirtyUnits)
	end

	local function seeUnit(unitID, allyTeamID)
		losStatus[unitID] = { [allyTeamID or SENSOR_ALLY] = INLOS }
	end

	local function radarUnit(unitID, allyTeamID)
		losStatus[unitID] = { [allyTeamID or SENSOR_ALLY] = INRADAR }
	end

	local function identifyUnit(unitID, allyTeamID)
		losStatus[unitID] = { [allyTeamID or SENSOR_ALLY] = INRADAR + PREVLOS + CONTRADAR }
	end

	local function hideUnit(unitID)
		losStatus[unitID] = nil
	end

	----------------------------------------------------------------
	--- Definition and filters -------------------------------------

	describe("its definition", function()
		it("declares its type and parameters", function()
			assert.are.equal('UnitUndetected', unitUndetected.type)

			local names = {}
			for _, parameter in ipairs(unitUndetected.parameters) do
				names[parameter.name] = true
			end
			assert.is_true(names.unitName)
			assert.is_true(names.unitDefName)
			assert.is_true(names.owningTeamID)
			assert.is_true(names.sensorAllyTeam)
			assert.is_true(names.sensorTypes)
			assert.are.same({ 'unitName', 'unitDefName' }, unitUndetected.parameters.requiresOneOf)
		end)

		local function loseUnit(triggerType, triggerID, context, unitID)
			seeUnit(unitID)
			update(triggerType, triggerID, context, { unitID })
			hideUnit(unitID)
			update(triggerType, triggerID, context, { unitID })
		end

		it("filters on unitName", function()
			local context, fired = newContext()
			context.DoesUnitHaveName = function() return false end
			loseUnit(trigger({ unitName = 'engineers' }), freshTriggerID(), context, freshUnitID())
			assert.are.equal(0, fired())
		end)

		it("filters on unitDefName", function()
			local context, fired = newContext()
			loseUnit(trigger({ unitDefName = 'corfast' }), freshTriggerID(), context, freshUnitID())
			assert.are.equal(0, fired())
		end)

		it("filters on owningTeamID", function()
			local context, fired = newContext()
			Spring.GetUnitTeam = function(_unitID) return 5 end
			local t = trigger({ unitDefName = 'armpw', owningTeamID = 3 })
			loseUnit(t, freshTriggerID(), context, freshUnitID())
			assert.are.equal(0, fired())
		end)

		it("filters on sensorAllyTeam", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw', sensorAllyTeam = SENSOR_ALLY }), freshTriggerID()
			local unitID = freshUnitID()

			-- Seen and then lost by an allyTeam this trigger does not watch.
			seeUnit(unitID, OTHER_ALLY)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(0, fired())
		end)

		it("filters on sensorTypes", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw', sensorTypes = { vision = true } }), freshTriggerID()
			local unitID = freshUnitID()

			-- Held and then lost by radar, which this trigger does not watch.
			radarUnit(unitID)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(0, fired())
		end)
	end)

	----------------------------------------------------------------
	--- Activation -------------------------------------------------

	describe("what it fires on", function()
		it("activates for a unit that stops being detected", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(1, fired())
		end)

		it("activates when the last allyTeam holding it loses it", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID, OTHER_ALLY)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(1, fired())
		end)
	end)

	describe("what it always ignores", function()
		it("ignores a unit that was never detected", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			update(t, triggerID, context, { unitID })
			update(t, triggerID, context, { unitID })

			assert.are.equal(0, fired())
		end)

		it("ignores a unit that was dead when its level changed", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			Spring.GetUnitIsDead = function(_unitID) return true end
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(0, fired())
		end)

		-- Wildlife sees plenty and means nothing by it, so losing Gaia's view loses nothing.
		-- We can specify the gaiaAllyTeam, still, in case that becomes a useful trigger.
		it("ignores a unit that only Gaia was holding", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID, GAIA_ALLY)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(0, fired())
		end)
	end)

	describe("rising and falling actions", function()
		it("activates on the fall", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			assert.are.equal(0, fired())

			hideUnit(unitID)
			update(t, triggerID, context, { unitID })
			assert.are.equal(1, fired())
		end)

		it("does not activate on the rise", function()
			local context, fired = newContext()
			local unitID = freshUnitID()
			seeUnit(unitID)
			update(trigger({ unitDefName = 'armpw' }), freshTriggerID(), context, { unitID })
			assert.are.equal(0, fired())
		end)
	end)

	----------------------------------------------------------------
	--- Activation counts ------------------------------------------

	describe("activation counts", function()
		it("adds nothing for updates that change no level", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })
			update(t, triggerID, context, { unitID })
			update(t, triggerID, context, { unitID })

			assert.are.equal(1, fired())
		end)

		it("adds one for each unit that falls in the same update", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local first, second = freshUnitID(), freshUnitID()

			seeUnit(first)
			seeUnit(second)
			update(t, triggerID, context, { first, second })
			assert.are.equal(0, fired())

			hideUnit(first)
			hideUnit(second)
			update(t, triggerID, context, { first, second })
			assert.are.equal(2, fired())
		end)

		it("adds one only for the unit that actually fell", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local falling, holding = freshUnitID(), freshUnitID()

			seeUnit(falling)
			seeUnit(holding)
			update(t, triggerID, context, { falling, holding })
			hideUnit(falling)
			update(t, triggerID, context, { falling, holding })

			assert.are.equal(1, fired())
		end)
	end)

	----------------------------------------------------------------
	--- Sensor sets ------------------------------------------------

	describe("sensorTypes", function()
		-- Seismic is left to detection_levels_spec, which makes these tests very awkward.
		local LEVELS = {
			{ name = 'radar',      reach = radarUnit },
			{ name = 'identified', reach = identifyUnit }, -- Part of radar. Unavailable _individually_ in the sensorType enum by choice.
			{ name = 'vision',     reach = seeUnit },
		}

		local function reportingLevels(sensorTypes)
			local reporting = {}
			for _, level in ipairs(LEVELS) do
				local context, fired = newContext()
				local t, triggerID = trigger({ unitDefName = 'armpw', sensorTypes = sensorTypes }), freshTriggerID()
				local unitID = freshUnitID()

				level.reach(unitID)
				update(t, triggerID, context, { unitID })
				hideUnit(unitID)
				update(t, triggerID, context, { unitID })

				if fired() > 0 then
					reporting[#reporting + 1] = level.name
				end
			end
			return reporting
		end

		it("reports every level but unseen when omitted", function()
			assert.are.same({ 'radar', 'identified', 'vision' }, reportingLevels(nil))
		end)

		it("reports only vision for a vision set", function()
			assert.are.same({ 'vision' }, reportingLevels({ vision = true }))
		end)

		it("reports both radar levels for a radar set", function()
			assert.are.same({ 'radar', 'identified' }, reportingLevels({ radar = true }))
		end)

		it("reports radar and vision together", function()
			assert.are.same({ 'radar', 'identified', 'vision' },
				reportingLevels({ radar = true, vision = true }))
		end)

		-- The same drop is a falloff for one sensorType set and no change for another.
		it("reports a drop from vision into radar only when radar is unwatched", function()
			local visionFired, bothFired

			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw', sensorTypes = { vision = true } }), freshTriggerID()
			local unitID = freshUnitID()
			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			radarUnit(unitID)
			update(t, triggerID, context, { unitID })
			visionFired = fired()

			context, fired = newContext()
			t, triggerID = trigger({ unitDefName = 'armpw', sensorTypes = { radar = true, vision = true } }), freshTriggerID()
			unitID = freshUnitID()
			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			radarUnit(unitID)
			update(t, triggerID, context, { unitID })
			bothFired = fired()

			assert.are.equal(1, visionFired)
			assert.are.equal(0, bothFired)
		end)
	end)

	----------------------------------------------------------------
	--- Deduplication ----------------------------------------------

	-- One sensor update raises several call-ins for the same unit, and the gadget folds them
	-- into one dirty mark. These pin that the trigger counts the level, not the events.
	describe("deduplication", function()
		it("activates once for a unit that stays undetected across updates", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			for _ = 1, 10 do
				update(t, triggerID, context, { unitID })
			end

			assert.are.equal(1, fired())
		end)

		-- Descending within a watched set is not a loss of detection.
		it("activates once for a unit falling from vision through radar to unseen", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			radarUnit(unitID)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(1, fired())
		end)
	end)

	----------------------------------------------------------------
	--- Settings and lifetime --------------------------------------

	describe("a repeating trigger", function()
		it("activates again for each new fall", function()
			local context, fired = newContext()
			local t = trigger({ unitDefName = 'armpw' }, { repeating = true })
			local triggerID = freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })
			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(2, fired())
		end)
	end)

	-- Death is not a loss of detection. A killed unit drops its latch and reports nothing.
	describe("a destroyed unit", function()
		it("reports nothing when it is destroyed while detected", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			onDestroyed(t, triggerID, context, unitID)

			assert.are.equal(0, fired())
		end)

		it("reports nothing on the sweep that follows its death", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			onDestroyed(t, triggerID, context, unitID)

			-- The unit is gone, so its level reads unseen, but the latch went with it.
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(0, fired())
		end)
	end)
end)
