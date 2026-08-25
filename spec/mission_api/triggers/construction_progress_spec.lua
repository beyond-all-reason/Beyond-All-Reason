require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time (so here), and
-- UnitDefs / Spring.GetUnitIsBeingBuilt / Spring.GetUnitTeam / Spring.GetUnitDefID in its handlers.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

_G.UnitDefs = { { name = "armsolar" }, { name = "armwar" } }

local constructionProgress = VFS.Include("luarules/mission_api/triggers/construction_progress.lua")
local onUnitBuildStep = constructionProgress.callins.UnitBuildStepPost
local onMetaUnitRemoved = constructionProgress.callins.MetaUnitRemoved

describe("mission_api.triggers.construction_progress", function()
	local world -- The trigger tracks units so that decay and reclaim do not rearm them.

	before_each(function()
		world = {}

		Spring.GetUnitTeam = function(unitID)
			local unit = world[unitID]
			return unit and unit.team
		end

		Spring.GetUnitDefID = function(unitID)
			local unit = world[unitID]
			return unit and unit.defID
		end

		Spring.GetUnitIsBeingBuilt = function(unitID)
			local unit = world[unitID]
			if not unit then
				return nil, nil
			end
			return unit.beingBuilt, unit.buildProgress
		end
	end)

	local function trigger(parameters, settings)
		return { parameters = parameters or {}, settings = settings or {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			DoesUnitHaveName = function()
				return true
			end,
			ActivateTrigger = function()
				fired = fired + 1
			end,
			ConstructionState = {},
		}
		return context, function()
			return fired
		end
	end

	local triggerID = "t"

	-- The part is the frame's net build step for the unit, and defaults to a small gain.
	local function step(t, context, unitID, part)
		onUnitBuildStep(t, triggerID, context, unitID, part or 0.1)
	end

	local function removed(t, context, unitID)
		onMetaUnitRemoved(t, triggerID, context, unitID)
	end

	-- Puts a unit under construction, on team 0, at the given progress.
	local function building(unitID, buildProgress, teamID, unitDefID)
		world[unitID] = {
			team = teamID or 0,
			defID = unitDefID or 1,
			beingBuilt = true,
			buildProgress = buildProgress,
		}
	end

	-- Puts a finished unit on team 0, as a unit spawned whole or built before the trigger.
	local function finished(unitID, teamID, unitDefID)
		world[unitID] = {
			team = teamID or 0,
			defID = unitDefID or 1,
			beingBuilt = false,
			buildProgress = 1.0,
		}
	end

	it("declares its type and parameters", function()
		assert.are.equal("ConstructionProgress", constructionProgress.type)
		local required = {}
		for _, parameter in ipairs(constructionProgress.parameters) do
			required[parameter.name] = parameter.required
		end
		assert.is_true(required.progress)
		assert.is_false(required.unitName)
		assert.is_false(required.unitDefName)
		assert.is_false(required.teamID)
		assert.are.same({ "unitName", "unitDefName" }, constructionProgress.parameters.requiresOneOf)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		building(100, 0.9, 0, 2)
		step(trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" }), context, 100)
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		building(100, 0.6)
		step(trigger({ teamID = 0, progress = 0.5, unitName = "target" }), context, 100)
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		building(100, 0.6, 1)
		step(trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" }), context, 100)
		assert.are.equal(0, fired())
	end)

	it("watches every team when teamID is omitted", function()
		local context, fired = newContext()
		building(100, 0.6, 1)
		step(trigger({ progress = 0.5, unitDefName = "armsolar" }), context, 100)
		assert.are.equal(1, fired())
	end)

	it("fires when a unit under construction reaches the threshold", function()
		local context, fired = newContext()
		building(100, 0.6)
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" })
		step(t, context, 100)
		step(t, context, 100)
		assert.are.equal(1, fired())
	end)

	it("does not fire while a unit is below the threshold", function()
		local context, fired = newContext()
		building(100, 0.4)
		step(trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" }), context, 100)
		assert.are.equal(0, fired())
	end)

	it("never fires for a unit never seen under construction, as repair steps it", function()
		local context, fired = newContext()
		finished(100)
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" })
		step(t, context, 100)
		step(t, context, 100)
		assert.are.equal(0, fired())
	end)

	it("fires at full progress as a tracked unit finishes (progress = 1.0)", function()
		local context, fired = newContext()
		local t = trigger({ teamID = 0, progress = 1.0, unitDefName = "armsolar" })
		building(100, 0.9)
		step(t, context, 100)
		assert.are.equal(0, fired())
		finished(100)
		step(t, context, 100)
		step(t, context, 100)
		assert.are.equal(1, fired())
	end)

	it("counts a unit once, even if it dips below the threshold and recrosses", function()
		local context, fired = newContext()
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" })
		building(100, 0.6)
		step(t, context, 100)
		world[100].buildProgress = 0.3
		step(t, context, 100)
		world[100].buildProgress = 0.6
		step(t, context, 100)
		assert.are.equal(1, fired())
	end)

	it("latches a unit that crosses unnamed, so that naming it later cannot fire", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function()
			return false
		end
		local t = trigger({ teamID = 0, progress = 0.5, unitName = "target" })
		building(100, 0.6)
		step(t, context, 100)
		assert.are.equal(0, fired())

		context.DoesUnitHaveName = function()
			return true
		end
		world[100].buildProgress = 0.8
		step(t, context, 100)
		assert.are.equal(0, fired())
	end)

	it("counts each distinct unit as it crosses the threshold over time", function()
		local context, fired = newContext()
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" })

		building(100, 0.6)
		step(t, context, 100)
		assert.are.equal(1, fired())

		building(101, 0.6)
		step(t, context, 101)
		assert.are.equal(2, fired())

		building(102, 0.6)
		step(t, context, 102)
		assert.are.equal(3, fired())
	end)

	it("fires for each unit that crosses in the same frame", function()
		local context, fired = newContext()
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" })
		building(100, 0.6)
		building(101, 0.8)
		step(t, context, 100)
		step(t, context, 101)
		assert.are.equal(2, fired())
	end)

	it("ignores a unit that is gone by the end of the frame", function()
		local context, fired = newContext()
		local t = trigger({ progress = 0.5, unitDefName = "armsolar" })
		building(100, 0.6)
		world[100] = nil
		step(t, context, 100)
		assert.are.equal(0, fired())
	end)

	-- These describe the removed UnitBuildStepTotal callin, which was handed the frame's net
	-- build step. UnitBuildStepPost receives only a unitID, so the trigger cannot currently
	-- tell building from reclaiming: a nanoframe reclaimed down past the threshold still
	-- fires. Pending until the gadget passes the step delta again.
	pending("ignores a frame whose steps net a loss", function()
		local context, fired = newContext()
		building(100, 0.6)
		step(trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" }), context, 100, -0.1)
		assert.are.equal(0, fired())
	end)

	pending("ignores a frame whose steps net zero", function()
		local context, fired = newContext()
		building(100, 0.6)
		step(trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" }), context, 100, 0)
		assert.are.equal(0, fired())
	end)

	it("forgets a unit when it is removed, so a reused unit ID arms again", function()
		local context, fired = newContext()
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = "armsolar" })
		building(100, 0.6)
		step(t, context, 100)
		assert.are.equal(1, fired())

		removed(t, context, 100)
		assert.is_nil(context.ConstructionState[triggerID][100])

		building(100, 0.6)
		step(t, context, 100)
		assert.are.equal(2, fired())
	end)
end)
