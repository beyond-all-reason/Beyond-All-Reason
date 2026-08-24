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

local unitDetected = VFS.Include('luarules/mission_api/triggers/unit_detected.lua')
local onDetectionUpdate = unitDetected.callins.DetectionUpdate -- an artificial callin
local onDestroyed = unitDetected.callins.UnitDestroyed

-- LosMask bits, as the engine reports them through Spring.GetUnitLosState(_, _, true).
local INLOS, INRADAR, PREVLOS, CONTRADAR = 1, 2, 4, 8

-- The allyTeam layout bakes into detection_levels at its load above, from the mission_api
-- spec_helper's stubs: two playing allyTeams and Gaia. These names address that layout.
local SENSOR_ALLY, OTHER_ALLY, GAIA_ALLY = 0, 1, 2

describe("mission_api.triggers.unit_detected", function()
	-- The latch lives in detection_levels, keyed by triggerID, and the spec harness caches
	-- includes, so each test takes fresh IDs rather than sharing state with the one before it.
	local losStatus
	local nextTriggerID, nextUnitID = 0, 1000

	before_each(function()
		losStatus = {}

		Spring.GetUnitLosState = function(unitID, allyTeamID, _raw)
			return losStatus[unitID] and losStatus[unitID][allyTeamID] or 0
		end
		Spring.GetUnitIsDead = function(_unitID) return false end
		Spring.GetUnitDefID = function(_unitID) return 1 end -- 'armpw', read back on an edge
		Spring.GetUnitTeam = function(_unitID) return 3 end
	end)

	local function freshTriggerID()
		nextTriggerID = nextTriggerID + 1
		return 'detected-' .. nextTriggerID
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
			DoesUnitHaveName = function() return true end,
			ActivateTrigger = function() fired = fired + 1 end,
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
			assert.are.equal('UnitDetected', unitDetected.type)

			local names = {}
			for _, parameter in ipairs(unitDetected.parameters) do
				names[parameter.name] = true
			end
			assert.is_true(names.unitName)
			assert.is_true(names.unitDefName)
			assert.is_true(names.owningTeamID)
			assert.is_true(names.sensorAllyTeam)
			assert.is_true(names.sensorTypes)
			assert.are.same({ 'unitName', 'unitDefName' }, unitDetected.parameters.requiresOneOf)
		end)

		it("filters on unitName", function()
			local context, fired = newContext()
			context.DoesUnitHaveName = function() return false end
			local unitID = freshUnitID()
			seeUnit(unitID)
			update(trigger({ unitName = 'engineers' }), freshTriggerID(), context, { unitID })
			assert.are.equal(0, fired())
		end)

		it("filters on unitDefName", function()
			local context, fired = newContext()
			local unitID = freshUnitID()
			seeUnit(unitID)
			update(trigger({ unitDefName = 'corfast' }), freshTriggerID(), context, { unitID })
			assert.are.equal(0, fired())
		end)

		it("filters on owningTeamID", function()
			local context, fired = newContext()
			Spring.GetUnitTeam = function(_unitID) return 5 end
			local unitID = freshUnitID()
			seeUnit(unitID)
			update(trigger({ unitDefName = 'armpw', owningTeamID = 3 }), freshTriggerID(), context, { unitID })
			assert.are.equal(0, fired())
		end)

		it("filters on sensorAllyTeam", function()
			local context, fired = newContext()
			local unitID = freshUnitID()
			seeUnit(unitID, OTHER_ALLY)
			local t = trigger({ unitDefName = 'armpw', sensorAllyTeam = SENSOR_ALLY })
			update(t, freshTriggerID(), context, { unitID })
			assert.are.equal(0, fired())
		end)

		it("filters on sensorTypes", function()
			local context, fired = newContext()
			local unitID = freshUnitID()
			radarUnit(unitID)
			local t = trigger({ unitDefName = 'armpw', sensorTypes = { vision = true } })
			update(t, freshTriggerID(), context, { unitID })
			assert.are.equal(0, fired())
		end)
	end)

	----------------------------------------------------------------
	--- Activation -------------------------------------------------

	describe("what it fires on", function()
		it("activates for a unit that becomes detected", function()
			local context, fired = newContext()
			local unitID = freshUnitID()
			seeUnit(unitID)
			update(trigger({ unitDefName = 'armpw' }), freshTriggerID(), context, { unitID })
			assert.are.equal(1, fired())
		end)

		it("activates for a unit detected only by another allyTeam, absent a sensorAllyTeam", function()
			local context, fired = newContext()
			local unitID = freshUnitID()
			seeUnit(unitID, OTHER_ALLY)
			update(trigger({ unitDefName = 'armpw' }), freshTriggerID(), context, { unitID })
			assert.are.equal(1, fired())
		end)
	end)

	describe("what it always ignores", function()
		it("ignores a unit that is never detected", function()
			local context, fired = newContext()
			local unitID = freshUnitID()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			update(t, triggerID, context, { unitID })
			update(t, triggerID, context, { unitID })
			assert.are.equal(0, fired())
		end)

		it("ignores a unit that was dead when its level changed", function()
			local context, fired = newContext()
			Spring.GetUnitIsDead = function(_unitID) return true end
			local unitID = freshUnitID()
			seeUnit(unitID)
			update(trigger({ unitDefName = 'armpw' }), freshTriggerID(), context, { unitID })
			assert.are.equal(0, fired())
		end)

		it("ignores a unit detected only by Gaia", function()
			local context, fired = newContext()
			local unitID = freshUnitID()
			seeUnit(unitID, GAIA_ALLY)
			update(trigger({ unitDefName = 'armpw' }), freshTriggerID(), context, { unitID })
			assert.are.equal(0, fired())
		end)
	end)

	describe("rising and falling", function()
		it("activates on the rise", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			update(t, triggerID, context, { unitID })
			assert.are.equal(0, fired())

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			assert.are.equal(1, fired())
		end)

		-- The fall belongs to UnitUndetected. This trigger must stay silent through it.
		it("does not activate on the fall", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			hideUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(1, fired())
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
			update(t, triggerID, context, { unitID })
			update(t, triggerID, context, { unitID })

			assert.are.equal(1, fired())
		end)

		it("adds one for each unit that rises in the same update", function()
			local context, fired = newContext()
			local first, second = freshUnitID(), freshUnitID()
			seeUnit(first)
			seeUnit(second)
			update(trigger({ unitDefName = 'armpw' }), freshTriggerID(), context, { first, second })
			assert.are.equal(2, fired())
		end)

		-- Activation carries no unit, so which subject earned the count is settled by
		-- construction: only one of the two can pass, and the count must be exactly one.
		it("adds one only for the unit that passes its filters", function()
			local context, fired = newContext()
			local matching, other = freshUnitID(), freshUnitID()
			Spring.GetUnitDefID = function(unitID) return unitID == matching and 1 or 2 end
			seeUnit(matching)
			seeUnit(other)
			update(trigger({ unitDefName = 'armpw' }), freshTriggerID(), context, { matching, other })
			assert.are.equal(1, fired())
		end)
	end)

	----------------------------------------------------------------
	--- Sensor sets ------------------------------------------------

	-- Every level a sensor set accepts, named, so that adding or reshaping a sensor shows up
	-- as a changed list rather than as a quietly different mask.
	describe("sensorTypes", function()
		-- Seismic is left to detection_levels_spec, which owns the contact it reads.
		local LEVELS = {
			{ name = 'radar',      reach = radarUnit },
			{ name = 'identified', reach = identifyUnit },
			{ name = 'vision',     reach = seeUnit },
		}

		local function activatingLevels(sensorTypes)
			local activating = {}
			for _, level in ipairs(LEVELS) do
				local context, fired = newContext()
				local unitID = freshUnitID()
				level.reach(unitID)
				local t = trigger({ unitDefName = 'armpw', sensorTypes = sensorTypes })
				update(t, freshTriggerID(), context, { unitID })
				if fired() > 0 then
					activating[#activating + 1] = level.name
				end
			end
			return activating
		end

		it("accepts every level but unseen when omitted", function()
			assert.are.same({ 'radar', 'identified', 'vision' }, activatingLevels(nil))
		end)

		it("accepts only vision for a vision set", function()
			assert.are.same({ 'vision' }, activatingLevels({ vision = true }))
		end)

		it("accepts both radar levels for a radar set", function()
			assert.are.same({ 'radar', 'identified' }, activatingLevels({ radar = true }))
		end)

		it("accepts no engine level for a seismic set", function()
			assert.are.same({}, activatingLevels({ seismic = true }))
		end)

		it("accepts radar and vision together", function()
			assert.are.same({ 'radar', 'identified', 'vision' },
				activatingLevels({ radar = true, vision = true }))
		end)

		it("accepts seismic and radar together", function()
			assert.are.same({ 'radar', 'identified' },
				activatingLevels({ seismic = true, radar = true }))
		end)

		-- Skipping radar in this set leaves a gap in the detection level, so this tests
		-- what it looks like to fall into a level-gap when crossing outside of the set.
		it("accepts seismic and vision without the radar levels between them", function()
			assert.are.same({ 'vision' },
				activatingLevels({ seismic = true, vision = true }))
		end)

		it("accepts every level for all three sensors", function()
			assert.are.same({ 'radar', 'identified', 'vision' },
				activatingLevels({ seismic = true, radar = true, vision = true }))
		end)
	end)

	----------------------------------------------------------------
	--- Deduplication ----------------------------------------------

	describe("deduplication", function()
		it("activates once for a unit held by two sensors at once", function()
			local context, fired = newContext()
			local unitID = freshUnitID()
			radarUnit(unitID)
			seeUnit(unitID) -- radar and vision reporting in the same frame
			update(trigger({ unitDefName = 'armpw' }), freshTriggerID(), context, { unitID })
			assert.are.equal(1, fired())
		end)

		it("activates once for a unit that stays detected across updates", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()
			seeUnit(unitID)

			for _ = 1, 10 do
				update(t, triggerID, context, { unitID })
			end
			assert.are.equal(1, fired())
		end)

		it("activates once for a unit climbing from radar into vision", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			radarUnit(unitID)
			update(t, triggerID, context, { unitID })
			seeUnit(unitID)
			update(t, triggerID, context, { unitID })

			assert.are.equal(1, fired())
		end)
	end)

	----------------------------------------------------------------
	--- Settings and lifetime --------------------------------------

	describe("a repeating trigger", function()
		it("activates again for each new rise", function()
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

			assert.are.equal(2, fired())
		end)
	end)

	describe("a destroyed unit", function()
		it("drops its latch without activating, and can be detected again", function()
			local context, fired = newContext()
			local t, triggerID = trigger({ unitDefName = 'armpw' }), freshTriggerID()
			local unitID = freshUnitID()

			seeUnit(unitID)
			update(t, triggerID, context, { unitID })
			onDestroyed(t, triggerID, context, unitID)
			assert.are.equal(1, fired())

			-- Rearmed: the same level now reads as a rise rather than as no change.
			update(t, triggerID, context, { unitID })
			assert.are.equal(2, fired())
		end)
	end)
end)
