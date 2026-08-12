require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

describe("MissionApiBuilder", function()

    describe("Build", function()
        it("creates the canonical GG['MissionAPI'] shape", function()
            local api = Builders.MissionApi.new():Build()

            assert.are.equal(0, api.Difficulty)
            assert.are.same({}, api.trackedUnitIDs)
            assert.are.same({}, api.trackedUnitNames)
            assert.are.same({}, api.trackedFeatureIDs)
            assert.are.same({}, api.trackedFeatureNames)
            assert.are.same({}, api.markerNames)
            assert.are.same({}, api.soundFiles)
            assert.are.same({}, api.soundQueue)
            assert.are.same({}, api.ManagedObjectives)
            assert.are.same({}, api.Objectives)
            assert.are.same({}, api.Stages)
            assert.are.same({}, api.Triggers)
            assert.are.same({}, api.Actions)
            assert.is_nil(api.CurrentStageID)
            assert.is_table(api.Modules)
        end)

        it("loads the real ParameterTypes module by default", function()
            local api = Builders.MissionApi.new():Build()

            assert.is_table(api.Modules.ParameterTypes)
            assert.is_table(api.Modules.ParameterTypes.Types)
        end)

        it("omits ParameterTypes when disabled", function()
            local api = Builders.MissionApi.new():WithoutParameterTypes():Build()

            assert.is_nil(api.Modules.ParameterTypes)
        end)

        it("exposes all module stubs", function()
            local api = Builders.MissionApi.new():Build()

            assert.is_function(api.Modules.Tracking.TrackUnit)
            assert.is_function(api.Modules.Loadout.SpawnUnitLoadout)
            assert.is_function(api.Modules.Sounds.PlaySound)
            assert.is_function(api.Modules.Objectives.ChangeStage)
        end)

        it("gives each built mock its own state", function()
            local apiA = Builders.MissionApi.new():Build()
            local apiB = Builders.MissionApi.new():Build()

            apiA.Modules.Tracking.TrackUnit("bots", 1)

            assert.is_false(apiA.Modules.Tracking.IsUnitNameUntracked("bots"))
            assert.is_true(apiB.Modules.Tracking.IsUnitNameUntracked("bots"))
        end)
    end)

    describe("mission data", function()
        it("seeds objectives, stages, triggers and actions", function()
            local api = Builders.MissionApi.new()
                :WithObjective("obj1", { textKey = "kill", amount = 3 })
                :WithStage("stage1", { objectives = { "obj1" } })
                :WithCurrentStage("stage1")
                :WithTrigger("trig1", { type = "TimeElapsed" })
                :WithAction("act1", { type = "Victory" })
                :WithManagedObjective("obj1", { kind = "kills" })
                :Build()

            assert.are.equal(3,        api.Objectives.obj1.amount)
            assert.are.same({ "obj1" }, api.Stages.stage1.objectives)
            assert.are.equal("stage1", api.CurrentStageID)
            assert.are.equal("TimeElapsed", api.Triggers.trig1.type)
            assert.are.equal("Victory",     api.Actions.act1.type)
            assert.are.equal("kills",       api.ManagedObjectives.obj1.kind)
        end)

        it("seeds markers, sound files and loadouts", function()
            local position = { x = 1, y = 2, z = 3 }
            local api = Builders.MissionApi.new()
                :WithMarker("base", position)
                :WithSoundFile("intro.wav", 120)
                :WithUnitLoadout({ { unitDefName = "armcom" } })
                :WithFeatureLoadout({ { featureDefName = "tree" } })
                :WithDifficulty(2)
                :Build()

            assert.are.same(position, api.markerNames.base)
            assert.are.equal(120, api.soundFiles["intro.wav"])
            assert.are.equal("armcom", api.UnitLoadout[1].unitDefName)
            assert.are.equal("tree",   api.FeatureLoadout[1].featureDefName)
            assert.are.equal(2, api.Difficulty)
        end)

        it("seeds action and trigger definitions", function()
            local api = Builders.MissionApi.new()
                :WithActionDefinitions({ Victory = {} })
                :WithTriggerDefinitions({ TimeElapsed = {} })
                :Build()

            assert.is_table(api.ActionDefinitions.Victory)
            assert.is_table(api.TriggerDefinitions.TimeElapsed)
        end)
    end)

    describe("Modules.Tracking", function()
        it("seeds tracked units bidirectionally", function()
            local api = Builders.MissionApi.new()
                :WithTrackedUnit("bots", 101)
                :WithTrackedUnit("bots", 102)
                :Build()

            assert.is_true(api.trackedUnitIDs.bots[101])
            assert.is_true(api.trackedUnitIDs.bots[102])
            assert.is_true(api.trackedUnitNames[101].bots)
            assert.is_false(api.Modules.Tracking.IsUnitNameUntracked("bots"))
            assert.is_true(api.Modules.Tracking.DoesUnitHaveName(101, "bots"))
        end)

        it("seeds tracked features bidirectionally", function()
            local api = Builders.MissionApi.new()
                :WithTrackedFeature("wreck", 7)
                :Build()

            assert.is_true(api.trackedFeatureIDs.wreck[7])
            assert.is_true(api.trackedFeatureNames[7].wreck)
            assert.is_false(api.Modules.Tracking.IsFeatureNameUntracked("wreck"))
            assert.is_true(api.Modules.Tracking.DoesFeatureHaveName(7, "wreck"))
        end)

        it("reports untracked names and ids", function()
            local api = Builders.MissionApi.new():Build()

            assert.is_true(api.Modules.Tracking.IsUnitNameUntracked("ghost"))
            assert.is_true(api.Modules.Tracking.IsUnitIDUntracked(999))
            assert.is_true(api.Modules.Tracking.IsFeatureNameUntracked("ghost"))
            assert.is_true(api.Modules.Tracking.IsFeatureIDUntracked(999))
        end)

        it("tracks units at runtime", function()
            local api = Builders.MissionApi.new():Build()

            api.Modules.Tracking.TrackUnit("scout", 5)

            assert.is_true(api.trackedUnitIDs.scout[5])
            assert.is_true(api.trackedUnitNames[5].scout)
        end)

        it("untracks a unit id and cleans up empty name entries", function()
            local api = Builders.MissionApi.new():WithTrackedUnit("solo", 1):Build()

            api.Modules.Tracking.UntrackUnitID(1)

            assert.is_nil(api.trackedUnitIDs.solo)
            assert.is_nil(api.trackedUnitNames[1])
        end)

        it("untracks a unit name and cleans up empty id entries", function()
            local api = Builders.MissionApi.new()
                :WithTrackedUnit("pair", 1)
                :WithTrackedUnit("pair", 2)
                :Build()

            api.Modules.Tracking.UntrackUnitName("pair")

            assert.is_nil(api.trackedUnitIDs.pair)
            assert.is_nil(api.trackedUnitNames[1])
            assert.is_nil(api.trackedUnitNames[2])
        end)

        it("keeps other names when untracking an id with multiple names", function()
            local api = Builders.MissionApi.new()
                :WithTrackedUnit("alpha", 1)
                :WithTrackedUnit("beta", 1)
                :Build()

            api.Modules.Tracking.UntrackUnitName("alpha")

            assert.is_nil(api.trackedUnitIDs.alpha)
            assert.is_true(api.trackedUnitIDs.beta[1])
            assert.is_true(api.trackedUnitNames[1].beta)
        end)
    end)

    describe("module call tracking", function()
        it("records Loadout calls and passes orders through unchanged", function()
            local api = Builders.MissionApi.new():Build()
            local orders = { { 10, {}, {} } }

            local result = api.Modules.Loadout.ConvertOrdersTargetingNames(orders)
            api.Modules.Loadout.SpawnUnitLoadout({ "a" })
            api.Modules.Loadout.SpawnFeatureLoadout({ "b" })

            assert.are.same(orders, result)
            assert.are.equal(1, #api._convertOrdersCalls)
            assert.are.equal(1, #api._spawnUnitCalls)
            assert.are.same({ "a" }, api._spawnUnitCalls[1].loadout)
            assert.are.equal(1, #api._spawnFeatureCalls)
            assert.are.same({ "b" }, api._spawnFeatureCalls[1].loadout)
        end)

        it("records Sounds calls", function()
            local api = Builders.MissionApi.new():Build()
            local position = { x = 1, y = 2, z = 3 }

            api.Modules.Sounds.PlaySound("a.wav", 0.5, position)
            api.Modules.Sounds.EnqueueSound("b.wav", 1, nil)
            api.Modules.Sounds.ProcessSoundQueue(30)

            assert.are.equal(1, #api._playSoundCalls)
            assert.are.equal("a.wav", api._playSoundCalls[1].soundfile)
            assert.are.equal(0.5,     api._playSoundCalls[1].volume)
            assert.are.same(position, api._playSoundCalls[1].position)
            assert.are.equal(1, #api._enqueueSoundCalls)
            assert.are.equal("b.wav", api._enqueueSoundCalls[1].soundfile)
            assert.are.equal(1, #api._processSoundQueueCalls)
            assert.are.equal(30, api._processSoundQueueCalls[1].frame)
        end)

        it("records Objectives calls", function()
            local api = Builders.MissionApi.new():Build()
            local objective = { textKey = "kill" }

            api.Modules.Objectives.ChangeStage("stage2")
            api.Modules.Objectives.TryAdvanceStage(objective)
            api.Modules.Objectives.UpdateObjectiveProgress("obj1", 0, "armcom", { "bots" }, 1, { kind = "kills" })
            api.Modules.Objectives.EchoObjectiveUpdate("obj1", objective)

            assert.are.equal("stage2", api._changeStageCalls[1].stageID)
            assert.are.same(objective, api._tryAdvanceCalls[1].objective)

            local progress = api._updateProgressCalls[1]
            assert.are.equal("obj1",   progress.objectiveID)
            assert.are.equal(0,        progress.teamID)
            assert.are.equal("armcom", progress.unitDefName)
            assert.are.same({ "bots" }, progress.unitNames)
            assert.are.equal(1,        progress.direction)
            assert.are.equal("kills",  progress.metadata.kind)

            assert.are.equal("obj1", api._echoCalls[1].objectiveID)
        end)

        it("clears every tracked call list via __clearCalls", function()
            local api = Builders.MissionApi.new():Build()

            api.Modules.Loadout.ConvertOrdersTargetingNames({})
            api.Modules.Loadout.SpawnUnitLoadout({})
            api.Modules.Loadout.SpawnFeatureLoadout({})
            api.Modules.Sounds.PlaySound("a.wav")
            api.Modules.Sounds.EnqueueSound("b.wav")
            api.Modules.Sounds.ProcessSoundQueue(1)
            api.Modules.Objectives.ChangeStage("s")
            api.Modules.Objectives.TryAdvanceStage({})
            api.Modules.Objectives.UpdateObjectiveProgress("o")
            api.Modules.Objectives.EchoObjectiveUpdate("o", {})

            api.__clearCalls()

            assert.are.equal(0, #api._convertOrdersCalls)
            assert.are.equal(0, #api._spawnUnitCalls)
            assert.are.equal(0, #api._spawnFeatureCalls)
            assert.are.equal(0, #api._playSoundCalls)
            assert.are.equal(0, #api._enqueueSoundCalls)
            assert.are.equal(0, #api._processSoundQueueCalls)
            assert.are.equal(0, #api._changeStageCalls)
            assert.are.equal(0, #api._tryAdvanceCalls)
            assert.are.equal(0, #api._updateProgressCalls)
            assert.are.equal(0, #api._echoCalls)
        end)
    end)

    describe("WithModule", function()
        it("overrides individual module functions", function()
            local api = Builders.MissionApi.new()
                :WithModule('Loadout', {
                    ConvertOrdersTargetingNames = function() return { "converted" } end,
                })
                :Build()

            assert.are.same({ "converted" }, api.Modules.Loadout.ConvertOrdersTargetingNames({}))
            -- untouched functions remain available
            assert.is_function(api.Modules.Loadout.SpawnUnitLoadout)
        end)

        it("adds entirely new modules", function()
            local api = Builders.MissionApi.new()
                :WithModule('Custom', { DoThing = function() return 42 end })
                :Build()

            assert.are.equal(42, api.Modules.Custom.DoThing())
        end)
    end)

    describe("Install", function()
        it("assigns the mock to GG['MissionAPI'] and returns it", function()
            local api = Builders.MissionApi.new():WithDifficulty(3):Install()

            assert.are.equal(api, GG['MissionAPI'])
            assert.are.equal(3, GG['MissionAPI'].Difficulty)
        end)

        it("keeps the GG['MissionAPI'] table identity stable across installs", function()
            local first = Builders.MissionApi.new():Install()
            local second = Builders.MissionApi.new():WithDifficulty(5):Install()

            assert.are.equal(first, second)
            assert.are.equal(first, GG['MissionAPI'])
            assert.are.equal(5, first.Difficulty)
        end)

        it("clears state left over from a previous install", function()
            Builders.MissionApi.new():WithTrackedUnit('bots', 1):WithCurrentStage('s1'):Install()
            local api = Builders.MissionApi.new():Install()

            assert.are.same({}, api.trackedUnitIDs)
            assert.is_nil(api.CurrentStageID)
            assert.is_true(api.Modules.Tracking.IsUnitNameUntracked('bots'))
        end)

        it("resets recorded calls on reinstall", function()
            local api = Builders.MissionApi.new():Install()
            api.Modules.Objectives.ChangeStage('s1')
            assert.are.equal(1, #api._changeStageCalls)

            Builders.MissionApi.new():Install()

            assert.are.equal(0, #api._changeStageCalls)
        end)

        it("bootstraps GG['MissionAPI'] when the module is included", function()
            -- The builder installs a default on first include, so action files
            -- can read Modules.ParameterTypes.Types at load time.
            assert.is_table(GG['MissionAPI'])
            assert.is_table(GG['MissionAPI'].Modules.ParameterTypes.Types)
        end)

        it("reclaims GG['MissionAPI'] if another spec replaced the table", function()
            local owned = Builders.MissionApi.new():Install()

            -- Simulate a spec that assigns its own table wholesale.
            GG['MissionAPI'] = { Modules = {} }

            local reinstalled = Builders.MissionApi.new():WithDifficulty(4):Install()

            assert.are.equal(owned, reinstalled)
            assert.are.equal(owned, GG['MissionAPI'])
            assert.are.equal(4, owned.Difficulty)
        end)
    end)

end)
