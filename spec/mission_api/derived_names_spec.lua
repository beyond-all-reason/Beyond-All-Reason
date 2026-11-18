local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

local UNITS_OWNED = 7
local PAWN = 1
local COMMANDER = 2

-- derived_names.lua and unit_query.lua keep the engine calls they make at load, so the stubs read this table.
---@type table<integer, { unitDefID: integer, teamID: integer, beingBuilt: boolean?, dead: boolean? }>
local units = {}
env.Spring.GetAllUnits = function()
	local unitIDs = {}
	for unitID in pairs(units) do
		unitIDs[#unitIDs + 1] = unitID
	end
	table.sort(unitIDs)
	return unitIDs
end
env.Spring.GetTeamUnits = function(teamID)
	local unitIDs = {}
	for unitID, unit in pairs(units) do
		if unit.teamID == teamID then
			unitIDs[#unitIDs + 1] = unitID
		end
	end
	table.sort(unitIDs)
	return unitIDs
end
env.Spring.GetUnitDefID = function(unitID)
	return units[unitID].unitDefID
end
env.Spring.GetUnitTeam = function(unitID)
	return units[unitID].teamID
end
env.Spring.GetUnitIsBeingBuilt = function(unitID)
	return units[unitID].beingBuilt == true
end
env.Spring.GetUnitIsDead = function(unitID)
	return units[unitID].dead == true
end
env.UnitDefs = { [PAWN] = { name = "armpw" }, [COMMANDER] = { name = "armcom" } }
env.UnitDefNames = { armpw = { id = PAWN }, armcom = { id = COMMANDER } }

describe("mission_api.derived_names", function()
	local missionApi, tracking, derivedNames ---@type table, table, table
	local countUnitNameChangeCalls

	local statisticsSpy = {
		CountUnitNameChange = function(conditionType, teamID, unitDefName, unitName, direction)
			countUnitNameChangeCalls[#countUnitNameChangeCalls + 1] = {
				conditionType = conditionType,
				teamID = teamID,
				unitDefName = unitDefName,
				unitName = unitName,
				direction = direction,
			}
		end,
	}

	local function count(teamID, unitDefName, direction)
		return {
			conditionType = UNITS_OWNED,
			teamID = teamID,
			unitDefName = unitDefName,
			unitName = "army",
			direction = direction,
		}
	end

	local function members()
		local unitIDs = missionApi.Modules.UnitQuery.MatchingUnits("army")
		table.sort(unitIDs)
		return unitIDs
	end

	-- The player's units, except the commander and the pawn, as processed: team names are IDs.
	local function addArmy()
		derivedNames.AddDerivedUnitName(
			"army",
			{ teamName = 0 },
			{ { unitName = "commander" }, { unitName = "pawn7" } }
		)
	end

	before_each(function()
		for unitID in pairs(units) do
			units[unitID] = nil
		end
		units[100] = { unitDefID = COMMANDER, teamID = 0 }
		units[101] = { unitDefID = PAWN, teamID = 0 }
		units[102] = { unitDefID = PAWN, teamID = 0 }
		units[103] = { unitDefID = PAWN, teamID = 1 }

		missionApi = MissionApiBuilder.new()
			:WithTrackedUnit("commander", 100)
			:WithTrackedUnit("pawn7", 101)
			:WithConditionDefinitions({ Types = { UnitsOwned = UNITS_OWNED } })
			:Install(env)
		tracking = missionApi.Modules.Tracking
		-- Included per test, since each install loads a fresh tracking module for it to listen to.
		derivedNames = MissionSpecEnv.include(env, "luarules/mission_api/derived_names.lua")
		derivedNames.Init({ statistics = statisticsSpy })
		countUnitNameChangeCalls = {}
	end)

	describe("AddDerivedUnitName", function()
		it("makes every finished unit matching the rule a member, counted", function()
			addArmy()

			assert.are.same({ 102 }, members())
			assert.are.same({ count(0, "armpw", 1) }, countUnitNameChangeCalls)
		end)

		it("excludes build frames and dead units", function()
			units[104] = { unitDefID = PAWN, teamID = 0, beingBuilt = true }
			units[105] = { unitDefID = PAWN, teamID = 0, dead = true }

			addArmy()

			assert.are.same({ 102 }, members())
		end)

		it("replaces the rule of a derived name with the same name", function()
			addArmy()
			countUnitNameChangeCalls = {}

			derivedNames.AddDerivedUnitName("army", { unitName = "commander" })

			assert.are.same({ 100 }, members())
			assert.are.same({ count(0, "armcom", 1), count(0, "armpw", -1) }, countUnitNameChangeCalls)
		end)

		it("leaves a derived name empty when a variable left an exception without fields", function()
			derivedNames.AddDerivedUnitName("army", { teamName = 0 }, { {} })

			assert.are.same({}, members())
		end)

		it("joins the unit being spawned under the name its rule refers to", function()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			missionApi.nameOfUnitBeingSpawned = "boss"
			missionApi.unitIDBeingSpawned = 104

			derivedNames.AddDerivedUnitName("army", { unitName = "boss" })

			missionApi.nameOfUnitBeingSpawned = nil
			missionApi.unitIDBeingSpawned = nil
			assert.are.same({ 104 }, members())
		end)
	end)

	describe("a name only its rule gives", function()
		it("refuses a derived name whose rule refers to a derived name", function()
			addArmy()

			derivedNames.AddDerivedUnitName("veterans", { unitName = "army" })

			assert.is_nil(missionApi.derivedNamesByUnitName.veterans)
		end)

		it("refuses a derived name that another rule refers to", function()
			derivedNames.AddDerivedUnitName("army", { teamName = 0 }, { { unitName = "reserve" } })

			derivedNames.AddDerivedUnitName("reserve", { teamName = 1 })

			assert.is_nil(missionApi.derivedNamesByUnitName.reserve)
		end)

		it("refuses a derived name units already have", function()
			derivedNames.AddDerivedUnitName("commander", { teamName = 0 })

			assert.is_nil(missionApi.derivedNamesByUnitName.commander)
		end)
	end)

	describe("RemoveDerivedUnitName", function()
		it("unnames every member, counted", function()
			addArmy()
			countUnitNameChangeCalls = {}

			derivedNames.RemoveDerivedUnitName("army")

			assert.are.same({}, members())
			assert.are.same({ count(0, "armpw", -1) }, countUnitNameChangeCalls)
		end)

		it("stops the derived name, so finished units no longer join", function()
			addArmy()
			derivedNames.RemoveDerivedUnitName("army")
			units[104] = { unitDefID = PAWN, teamID = 0 }

			derivedNames.OnUnitFinished(104, units[104].unitDefID)

			assert.are.same({}, members())
		end)

		it("lets the name be added again", function()
			addArmy()
			derivedNames.RemoveDerivedUnitName("army")

			addArmy()

			assert.are.same({ 102 }, members())
		end)

		it("does nothing for a name no rule derives", function()
			derivedNames.RemoveDerivedUnitName("army")

			assert.are.same({}, countUnitNameChangeCalls)
		end)
	end)

	describe("OnUnitFinished", function()
		it("joins a unit that finished building, counted", function()
			addArmy()
			countUnitNameChangeCalls = {}
			units[104] = { unitDefID = PAWN, teamID = 0 }

			derivedNames.OnUnitFinished(104, units[104].unitDefID)

			assert.are.same({ 102, 104 }, members())
			assert.are.same({ count(0, "armpw", 1) }, countUnitNameChangeCalls)
		end)

		it("joins a unit by the team it is on, when a gadget gave it away before this one heard of it", function()
			addArmy()
			derivedNames.AddDerivedUnitName("raiders", { teamName = 1 })
			units[104] = { unitDefID = PAWN, teamID = 1 }

			derivedNames.OnUnitFinished(104, PAWN)

			assert.are.same({ 102 }, members())
			assert.is_true(tracking.DoesUnitHaveName(104, "raiders"))
		end)

		it("excludes a unit that a gadget destroyed before this one heard of it", function()
			addArmy()
			units[104] = { unitDefID = PAWN, teamID = 0, dead = true }

			derivedNames.OnUnitFinished(104, PAWN)

			assert.are.same({ 102 }, members())
		end)

		it("excludes a unit matching an exception", function()
			addArmy()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			tracking.TrackUnit("pawn7", 104)

			derivedNames.OnUnitFinished(104, units[104].unitDefID)

			assert.are.same({ 102 }, members())
		end)

		it("excludes a unit being spawned with an excepted loadout name", function()
			addArmy()
			units[104] = { unitDefID = COMMANDER, teamID = 0 }
			missionApi.nameOfUnitBeingSpawned = "commander"
			missionApi.unitIDBeingSpawned = 104

			derivedNames.OnUnitFinished(104, units[104].unitDefID)

			missionApi.nameOfUnitBeingSpawned = nil
			missionApi.unitIDBeingSpawned = nil
			assert.are.same({ 102 }, members())
		end)
	end)

	describe("OnUnitReverseBuilt", function()
		it("unnames a member that is a build frame again, counted", function()
			addArmy()
			countUnitNameChangeCalls = {}
			units[102].beingBuilt = true

			derivedNames.OnUnitReverseBuilt(102, units[102].unitDefID)

			assert.are.same({}, members())
			assert.are.same({ count(0, "armpw", -1) }, countUnitNameChangeCalls)
		end)
	end)

	describe("a unit changing team", function()
		-- The order of the MetaUnit call-ins in a transfer, with the engine's team change between them.
		local function transfer(unitID, teamID)
			derivedNames.OnMetaUnitRemoved(unitID, units[unitID].unitDefID, units[unitID].teamID)
			units[unitID].teamID = teamID
			derivedNames.OnMetaUnitAdded(unitID, units[unitID].unitDefID, units[unitID].teamID)
		end

		it("joins a unit given to the filter's team, uncounted", function()
			addArmy()
			countUnitNameChangeCalls = {}

			transfer(103, 0)

			assert.are.same({ 102, 103 }, members())
			assert.are.same({}, countUnitNameChangeCalls)
		end)

		it("unnames a member given to another team, uncounted", function()
			addArmy()
			countUnitNameChangeCalls = {}

			transfer(102, 1)

			assert.are.same({}, members())
			assert.are.same({}, countUnitNameChangeCalls)
		end)

		it("keeps the name until MetaUnitAdded, so UnitTaken's triggers see the old membership", function()
			addArmy()

			derivedNames.OnMetaUnitRemoved(102, units[102].unitDefID, units[102].teamID)
			units[102].teamID = 1

			assert.are.same({ 102 }, members())
		end)

		it("leaves a build frame out", function()
			addArmy()
			units[103].beingBuilt = true

			transfer(103, 0)

			assert.are.same({ 102 }, members())
		end)

		it("excludes a unit killed during UnitTaken's dispatch", function()
			addArmy()
			derivedNames.OnMetaUnitRemoved(103, units[103].unitDefID, units[103].teamID)
			units[103].dead = true
			units[103].teamID = 0

			derivedNames.OnMetaUnitAdded(103, units[103].unitDefID, units[103].teamID)

			assert.are.same({ 102 }, members())
		end)

		it(
			"does not count a leave by naming during UnitTaken's dispatch, as MetaUnitRemoved uncounted the unit",
			function()
				addArmy()
				countUnitNameChangeCalls = {}
				derivedNames.OnMetaUnitRemoved(102, units[102].unitDefID, units[102].teamID)

				tracking.TrackUnit("commander", 102)

				assert.are.same({}, members())
				assert.are.same({}, countUnitNameChangeCalls)
			end
		)

		it("does not count a derived name removed during UnitTaken's dispatch", function()
			addArmy()
			countUnitNameChangeCalls = {}
			derivedNames.OnMetaUnitRemoved(102, units[102].unitDefID, units[102].teamID)

			derivedNames.RemoveDerivedUnitName("army")

			assert.are.same({}, countUnitNameChangeCalls)
		end)

		it("counts a derived name removed while a member's death is still to be uncounted", function()
			addArmy()
			countUnitNameChangeCalls = {}
			units[102].dead = true

			derivedNames.RemoveDerivedUnitName("army")

			assert.are.same({ count(0, "armpw", -1) }, countUnitNameChangeCalls)
		end)

		it("does not count a derived name removed once MetaUnitRemoved uncounted a dying member", function()
			addArmy()
			countUnitNameChangeCalls = {}
			units[102].dead = true
			derivedNames.OnMetaUnitRemoved(102, units[102].unitDefID, units[102].teamID)

			derivedNames.RemoveDerivedUnitName("army")

			assert.are.same({}, countUnitNameChangeCalls)
		end)

		it("counts a new unit under the ID of one that died", function()
			addArmy()
			units[102].dead = true
			derivedNames.OnMetaUnitRemoved(102, units[102].unitDefID, units[102].teamID)
			tracking.UntrackUnitID(102)
			derivedNames.OnUnitDestroyed(102)
			countUnitNameChangeCalls = {}
			units[102] = { unitDefID = PAWN, teamID = 0 }

			derivedNames.OnUnitFinished(102, PAWN)

			assert.are.same({ count(0, "armpw", 1) }, countUnitNameChangeCalls)
		end)

		it("leaves a unit created on its team to be updated when it finishes", function()
			addArmy()
			units[104] = { unitDefID = PAWN, teamID = 0 }

			derivedNames.OnMetaUnitAdded(104, units[104].unitDefID, units[104].teamID)

			assert.are.same({ 102 }, members())
		end)
	end)

	describe("a unit being added", function()
		it("joins uncounted during MetaUnitAdded's dispatch, which counts it with its names after", function()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			derivedNames.OnMetaUnitAdded(104, units[104].unitDefID, units[104].teamID)

			addArmy()

			assert.are.same({ 102, 104 }, members())
			assert.are.same({ count(0, "armpw", 1) }, countUnitNameChangeCalls)
		end)

		it("is counted again after OnMetaUnitAddedCounted", function()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			derivedNames.OnMetaUnitAdded(104, units[104].unitDefID, units[104].teamID)
			addArmy()
			derivedNames.OnMetaUnitAddedCounted(104)
			countUnitNameChangeCalls = {}

			tracking.TrackUnit("pawn7", 104)

			assert.are.same({ count(0, "armpw", -1) }, countUnitNameChangeCalls)
		end)
	end)

	describe("a member's death", function()
		it("keeps the name through UnitDestroyed's dispatch, so UnitKilled on the derived name fires", function()
			local unitKilled = MissionSpecEnv.include(env, "luarules/mission_api/conditions/unit_killed.lua")
			local activated = {}
			local context = {
				DoesUnitHaveName = tracking.DoesUnitHaveName,
				ActivateTrigger = function(trigger)
					activated[#activated + 1] = trigger
					return true
				end,
			}
			local trigger = { parameters = { unitName = "army" } }
			addArmy()
			units[102].dead = true

			unitKilled.callins.UnitDestroyed(trigger, "t", context, 102, PAWN, 0)

			assert.are.same({ trigger }, activated)
		end)

		it("is not counted by the derived name, as its names are uncounted on removal", function()
			addArmy()
			countUnitNameChangeCalls = {}
			units[102].dead = true

			tracking.UntrackUnitID(102)

			assert.are.same({}, members())
			assert.are.same({}, countUnitNameChangeCalls)
		end)
	end)

	describe("a name given or taken by anything else", function()
		it("unnames a member named with an excepted name, counted", function()
			addArmy()
			countUnitNameChangeCalls = {}

			tracking.TrackUnit("commander", 102)

			assert.are.same({}, members())
			assert.are.same({ count(0, "armpw", -1) }, countUnitNameChangeCalls)
		end)

		it("names a unit unnamed from its excepted name, counted", function()
			addArmy()
			countUnitNameChangeCalls = {}

			tracking.UntrackUnitName("pawn7")

			assert.are.same({ 101, 102 }, members())
			assert.are.same({ count(0, "armpw", 1) }, countUnitNameChangeCalls)
		end)

		it("ignores a name the rule does not refer to", function()
			addArmy()
			countUnitNameChangeCalls = {}

			tracking.TrackUnit("scout", 102)
			tracking.TrackUnit("scout", 103)

			assert.are.same({ 102 }, members())
			assert.are.same({}, countUnitNameChangeCalls)
		end)

		it("ignores a dying unit", function()
			addArmy()
			countUnitNameChangeCalls = {}
			units[102].dead = true

			tracking.TrackUnit("commander", 102)

			assert.are.same({}, countUnitNameChangeCalls)
		end)
	end)

	describe("counting", function()
		local statistics, batch, unitsOwnedTriggers, activated

		before_each(function()
			unitsOwnedTriggers = {}
			activated = {}
			statistics = MissionSpecEnv.include(env, "luarules/mission_api/statistics.lua")
			batch = MissionSpecEnv.include(env, "luarules/mission_api/batch.lua")
			local function activateTrigger(trigger)
				activated[#activated + 1] = trigger
				trigger.repeatCount = trigger.repeatCount + 1
				if trigger.runActions then
					trigger.runActions()
				end
				return true
			end
			statistics.Init({
				processTriggersOfType = function(conditionType, func)
					for triggerID, trigger in pairs(unitsOwnedTriggers) do
						if trigger.type == conditionType then
							func(trigger, triggerID)
						end
					end
				end,
				activateTrigger = activateTrigger,
				-- Fires on entering the bounds, as the triggers gadget does.
				evaluateMetric = function(trigger, value)
					local satisfied = (trigger.atLeast == nil or value >= trigger.atLeast)
						and (trigger.atMost == nil or value <= trigger.atMost)
					if satisfied and not trigger.metricSatisfied then
						trigger.metricSatisfied = true
						activateTrigger(trigger)
					elseif not satisfied then
						trigger.metricSatisfied = false
					end
				end,
				conditionKinds = { [UNITS_OWNED] = "metric" },
				batch = batch,
			})
			derivedNames.Init({ statistics = statistics })
		end)

		local function unitsOwned(parameters, atLeast, atMost)
			return { type = UNITS_OWNED, parameters = parameters, atLeast = atLeast, atMost = atMost, repeatCount = 0 }
		end

		-- As the triggers gadget's call-ins and trigger activations do.
		local function inScope(func, ...)
			batch.Start()
			func(...)
			batch.End()
		end

		it("keeps a UnitsOwned count on the derived name true", function()
			unitsOwnedTriggers.armyGone = unitsOwned({ teamName = 0, unitName = "army" }, nil, 0)
			addArmy()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			derivedNames.OnUnitFinished(104, units[104].unitDefID)

			tracking.TrackUnit("commander", 102)
			assert.are.same({}, activated)

			units[104].beingBuilt = true
			derivedNames.OnUnitReverseBuilt(104, units[104].unitDefID)
			assert.are.same({ unitsOwnedTriggers.armyGone }, activated)
		end)

		it("updates a unit in every derived name before an activation can change the unit again", function()
			-- Each activation names the new unit as an exception to both derived names.
			local function nameRecruitCommander()
				tracking.TrackUnit("commander", 104)
			end
			unitsOwnedTriggers.armyRaised = unitsOwned({ teamName = 0, unitName = "army" }, 2)
			unitsOwnedTriggers.armyRaised.runActions = nameRecruitCommander
			unitsOwnedTriggers.guardRaised = unitsOwned({ teamName = 0, unitName = "guard" }, 2)
			unitsOwnedTriggers.guardRaised.runActions = nameRecruitCommander
			unitsOwnedTriggers.armyGone = unitsOwned({ teamName = 0, unitName = "army" }, nil, 0)
			unitsOwnedTriggers.guardGone = unitsOwned({ teamName = 0, unitName = "guard" }, nil, 0)
			addArmy()
			derivedNames.AddDerivedUnitName(
				"guard",
				{ teamName = 0 },
				{ { unitName = "commander" }, { unitName = "pawn7" } }
			)
			units[104] = { unitDefID = PAWN, teamID = 0 }

			inScope(derivedNames.OnUnitFinished, 104, units[104].unitDefID)

			assert.is_false(table.contains(activated, unitsOwnedTriggers.armyGone))
			assert.is_false(table.contains(activated, unitsOwnedTriggers.guardGone))
			assert.are.same({ 102 }, members())
		end)

		it("lets a trigger fired by a derived name's removal add it again", function()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			unitsOwnedTriggers.armyGone = unitsOwned({ teamName = 0, unitName = "army" }, nil, 0)
			unitsOwnedTriggers.armyGone.runActions = addArmy
			addArmy()

			inScope(derivedNames.RemoveDerivedUnitName, "army")

			assert.are.same({ unitsOwnedTriggers.armyGone }, activated)
			assert.is_not_nil(missionApi.derivedNamesByUnitName.army)
			assert.are.same({ 102, 104 }, members())
		end)

		it("activates nothing for a count that a pass moved away from again", function()
			unitsOwnedTriggers.armyGone = unitsOwned({ teamName = 0, unitName = "army" }, nil, 0)
			addArmy()

			-- The old rule's only member leaves, and the commander joins, in one pass.
			inScope(derivedNames.AddDerivedUnitName, "army", { unitName = "commander" })

			assert.are.same({}, activated)
			assert.are.same({ 100 }, members())
		end)

		it("leaves a UnitsOwned count by type alone", function()
			unitsOwnedTriggers.pawns = unitsOwned({ teamName = 0, unitDefName = "armpw" }, 1)

			addArmy()

			assert.are.same({}, activated)
		end)
	end)
end)
