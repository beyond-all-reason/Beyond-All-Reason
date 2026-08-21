require("spec_helper")
require("mission_api.spec_helper")

-- detection_levels reads the shared SeismicContacts module at load, so it is stubbed first.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}

local seismicContacts = {}
GG['MissionAPI'].Modules.SeismicContacts = {
	IsContact = function(unitID, allyTeamID)
		return seismicContacts[allyTeamID] ~= nil and seismicContacts[allyTeamID][unitID] == true
	end,
}

-- LosMask bits, as the engine reports them through Spring.GetUnitLosState(_, _, true).
local INLOS, INRADAR, PREVLOS, CONTRADAR = 1, 2, 4, 8

-- LEVEL in the module: 2^level, over 0:unseen / 1:seismic / 2:radar / 3:typed / 4:vision.
local UNSEEN, SEISMIC, RADAR, IDENTIFIED, VISION = 1, 2, 4, 8, 16

describe("mission_api.detection_levels", function()
	local DetectionLevels
	local losStatusByAllyTeam
	local triggerID = 'detected'

	before_each(function()
		losStatusByAllyTeam = {}
		seismicContacts = {}
		Spring.GetUnitLosState = function(_unitID, allyTeamID, _raw)
			return losStatusByAllyTeam[allyTeamID] or 0
		end
		-- Two playing allyTeams and Gaia, which mission_api's spec_helper also assumes.
		Spring.GetAllyTeamList = function() return { 0, 1, 2 } end
		Spring.GetGaiaTeamID = function() return 2 end
		Spring.GetTeamAllyTeamID = function(teamID) return teamID end
		-- The module resolves the allyTeam layout at load, so each test reloads it after
		-- the stubs above are in place. The reload also leaves the latch table empty.
		DetectionLevels = VFS.Include('luarules/mission_api/detection_levels.lua')
	end)

	describe("detection levels derive from losStatus", function()
		it("reads no bits as unseen", function()
			assert.are.equal(UNSEEN, DetectionLevels.LevelBitOf(100, 0))
		end)

		it("reads INLOS as vision", function()
			losStatusByAllyTeam[0] = INLOS
			assert.are.equal(VISION, DetectionLevels.LevelBitOf(100, 0))
		end)

		it("reads INRADAR alone as unidentified radar", function()
			losStatusByAllyTeam[0] = INRADAR
			assert.are.equal(RADAR, DetectionLevels.LevelBitOf(100, 0))
		end)

		-- Currently unused but should not be wrong, in any case:
		it("reads INRADAR with both memory bits as identified radar", function()
			losStatusByAllyTeam[0] = INRADAR + PREVLOS + CONTRADAR
			assert.are.equal(IDENTIFIED, DetectionLevels.LevelBitOf(100, 0))
		end)

		-- The engine's unit isTyped tests want both bits, not either one.
		it("reads INRADAR with only one memory bit as unidentified", function()
			losStatusByAllyTeam[0] = INRADAR + PREVLOS
			assert.are.equal(RADAR, DetectionLevels.LevelBitOf(100, 0))
		end)

		it("prefers vision over any radar bits held at once", function()
			losStatusByAllyTeam[0] = INLOS + INRADAR + PREVLOS + CONTRADAR
			assert.are.equal(VISION, DetectionLevels.LevelBitOf(100, 0))
		end)
	end)

	describe("seismic detection as the lowest level", function()
		it("reads a contact as seismic EVEN when the engine reports nothing", function()
			seismicContacts[0] = { [100] = true }
			assert.are.equal(SEISMIC, DetectionLevels.LevelBitOf(100, 0))
		end)

		it("is outranked by radar for the same allyTeam", function()
			seismicContacts[0] = { [100] = true }
			losStatusByAllyTeam[0] = INRADAR
			assert.are.equal(RADAR, DetectionLevels.LevelBitOf(100, 0))
		end)
	end)

	describe("without a sensorAllyTeam", function()
		-- allyTeams are 0:reference, 1:enemy, 2:gaia
		it("ignores Gaia, which sees plenty and means nothing by it", function()
			losStatusByAllyTeam[2] = INLOS
			assert.are.equal(UNSEEN, DetectionLevels.LevelBitOf(100, nil))
		end)

		it("still reports Gaia when asked for it by name", function()
			losStatusByAllyTeam[2] = INLOS
			assert.are.equal(VISION, DetectionLevels.LevelBitOf(100, 2))
		end)

		it("takes the highest level held by any allyTeam", function()
			losStatusByAllyTeam[0] = INRADAR
			losStatusByAllyTeam[1] = INLOS
			assert.are.equal(VISION, DetectionLevels.LevelBitOf(100, nil))
		end)
	end)

	describe("sensor masks", function()
		it("compiles a single sensor to its own levels", function()
			assert.are.equal(VISION, DetectionLevels.CompileLevelMask({ vision = true }))
			assert.are.equal(SEISMIC, DetectionLevels.CompileLevelMask({ seismic = true }))
		end)

		it("compiles radar to both of its levels", function()
			assert.are.equal(RADAR + IDENTIFIED, DetectionLevels.CompileLevelMask({ radar = true }))
		end)

		-- omitting an enumSet parameter permits every value.
		it("compiles an omitted sensorTypes to any detection at all", function()
			assert.are.equal(SEISMIC + RADAR + IDENTIFIED + VISION, DetectionLevels.CompileLevelMask(nil)) -- TODO: IDENTIFIED sneaks in though it cannot be specified?
		end)

		it("never admits the unseen level", function()
			local mask = DetectionLevels.CompileLevelMask(nil)
			assert.are.equal(0, math.bit_and(mask, UNSEEN))
		end)
	end)

	-- The latch is only reachable through the handler, which is the path the triggers take.
	describe("the latch", function()
		local FIRES_ON_DETECTED, FIRES_ON_UNDETECTED = true, false

		local fired
		local context
		local trigger

		before_each(function()
			fired = 0
			-- Fresh per test: the compiled level mask caches onto the trigger it belongs to.
			trigger = { parameters = {}, _settings = {} }
			context = {
				ActivateTrigger = function() fired = fired + 1 end,
				DoesUnitHaveName = function() return true end,
			}
			Spring.GetUnitIsDead = function() return false end
			Spring.GetUnitDefID = function() return 1 end
		end)

		local function sweep(handler, ...)
			DetectionLevels.BeginUpdate()
			handler(trigger, triggerID, context, ...)
		end

		local function matchesAnything() return true end

		it("reports a rise once, however many updates repeat it", function()
			local onDetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, matchesAnything)
			losStatusByAllyTeam[0] = INLOS
			sweep(onDetected, { [100] = true })
			sweep(onDetected, { [100] = true })
			sweep(onDetected, { [100] = true })
			assert.are.equal(1, fired)
		end)

		it("reports a fall once, and rearms for the next rise", function()
			local onUndetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_UNDETECTED, matchesAnything)
			losStatusByAllyTeam[0] = INLOS
			sweep(onUndetected, { [100] = true }) -- rises, which this trigger does not report
			assert.are.equal(0, fired)

			losStatusByAllyTeam[0] = nil
			sweep(onUndetected, { [100] = true })
			sweep(onUndetected, { [100] = true })
			assert.are.equal(1, fired)

			losStatusByAllyTeam[0] = INLOS
			sweep(onUndetected, { [100] = true }) -- rearmed: rises again, still unreported
			losStatusByAllyTeam[0] = nil
			sweep(onUndetected, { [100] = true })
			assert.are.equal(2, fired)
		end)

		it("does not report a fall for a unit that never rose", function()
			local onUndetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_UNDETECTED, matchesAnything)
			sweep(onUndetected, { [100] = true })
			sweep(onUndetected, { [100] = true })
			assert.are.equal(0, fired)
		end)

		it("holds each unit's edges apart", function()
			local onDetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, matchesAnything)
			losStatusByAllyTeam[0] = INLOS
			sweep(onDetected, { [100] = true, [101] = true })
			assert.are.equal(2, fired)
		end)

		it("does not report a unit that was dead when its level changed", function()
			local onDetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, matchesAnything)
			Spring.GetUnitIsDead = function() return true end
			losStatusByAllyTeam[0] = INLOS
			sweep(onDetected, { [100] = true })
			assert.are.equal(0, fired)
		end)

		it("does not report a unit its own filters reject", function()
			local onDetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, function() return false end)
			losStatusByAllyTeam[0] = INLOS
			sweep(onDetected, { [100] = true })
			assert.are.equal(0, fired)
		end)

		it("forgets a unit without reporting, since death is not a loss of detection", function()
			local onUndetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_UNDETECTED, matchesAnything)
			losStatusByAllyTeam[0] = INLOS
			sweep(onUndetected, { [100] = true })
			DetectionLevels.Clear(triggerID, 100) -- called in UnitDestroyed
			losStatusByAllyTeam[0] = nil
			sweep(onUndetected, { [100] = true })
			assert.are.equal(0, fired)
		end)
	end)

	-- Every trigger of both types runs over the same dirty units, so a sweep resolves each
	-- unit's level once and hands the same answer to all of them.
	describe("the sweep cache", function()
		local FIRES_ON_DETECTED, FIRES_ON_UNDETECTED = true, false

		local context
		local losStateReads

		before_each(function()
			context = {
				ActivateTrigger = function() end,
				DoesUnitHaveName = function() return true end,
			}
			Spring.GetUnitIsDead = function() return false end
			Spring.GetUnitDefID = function() return 1 end

			losStateReads = 0
			local getUnitLosState = Spring.GetUnitLosState
			Spring.GetUnitLosState = function(unitID, allyTeamID, raw)
				losStateReads = losStateReads + 1
				return getUnitLosState(unitID, allyTeamID, raw)
			end
		end)

		local function matchesAnything() return true end

		local function newTrigger(parameters)
			return { parameters = parameters or {}, settings = {} }
		end

		-- The layout is two playing allyTeams, so an unseen unit costs one read of each.
		it("resolves each allyTeam once for the whole sweep", function()
			local onDetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, matchesAnything)
			local onUndetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_UNDETECTED, matchesAnything)

			DetectionLevels.BeginUpdate()
			onDetected(newTrigger(), 'detected', context, { [100] = true })
			onUndetected(newTrigger(), 'undetected', context, { [100] = true })

			assert.are.equal(2, losStateReads)
		end)

		it("resolves again in the sweep that follows", function()
			local onDetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, matchesAnything)

			DetectionLevels.BeginUpdate()
			onDetected(newTrigger(), 'detected', context, { [100] = true })
			DetectionLevels.BeginUpdate()
			onDetected(newTrigger(), 'detected', context, { [100] = true })

			assert.are.equal(4, losStateReads)
		end)

		-- Resolving per allyTeam, rather than per trigger, is what shares these two.
		it("shares a named sensorAllyTeam with the triggers that name none", function()
			local onDetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, matchesAnything)

			DetectionLevels.BeginUpdate()
			onDetected(newTrigger({ sensorAllyTeam = 0 }), 'named', context, { [100] = true })
			onDetected(newTrigger(), 'unnamed', context, { [100] = true })

			assert.are.equal(2, losStateReads)
		end)

		it("stops looking once a level cannot be outranked", function()
			local onDetected = DetectionLevels.NewDetectionUpdate(FIRES_ON_DETECTED, matchesAnything)
			losStatusByAllyTeam[0] = INLOS

			DetectionLevels.BeginUpdate()
			onDetected(newTrigger(), 'detected', context, { [100] = true })

			assert.are.equal(1, losStateReads)
		end)
	end)
end)
