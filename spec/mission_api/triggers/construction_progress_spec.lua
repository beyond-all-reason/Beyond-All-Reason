require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time (so here), and
-- UnitDefNames / Spring.GetTeamUnits(ByDefs) / Spring.GetUnitIsBeingBuilt inside its handler.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefNames = { armsolar = { id = 1 }, armwar = { id = 2 } }

local constructionProgress = VFS.Include('luarules/mission_api/triggers/construction_progress.lua')
local onGameFrame = constructionProgress.callins.GameFrame

describe("mission_api.triggers.construction_progress", function()
	local world -- The trigger tracks units to avoid re-arming itself when they decay/are reclaimed.

	before_each(function()
		world = {}

		Spring.GetTeamUnits = function(_teamID)
			local unitIDs = {}
			for unitID in pairs(world) do unitIDs[#unitIDs + 1] = unitID end
			table.sort(unitIDs)
			return unitIDs
		end

		Spring.GetTeamUnitsByDefs = function(_teamID, unitDefID)
			local unitIDs = {}
			for unitID, unit in pairs(world) do
				if unit.defID == unitDefID then unitIDs[#unitIDs + 1] = unitID end
			end
			table.sort(unitIDs)
			return unitIDs
		end

		Spring.GetUnitIsBeingBuilt = function(unitID)
			local unit = world[unitID]
			if not unit then return nil end
			return unit.beingBuilt, unit.buildProgress
		end
	end)

	local function trigger(parameters, settings)
		return { parameters = parameters or {}, settings = settings or {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			DoesUnitHaveName = function() return true end,
			ActivateTrigger = function() fired = fired + 1 end,
			ConstructionState = {},
		}
		return context, function() return fired end
	end

	local triggerID = 't'

	local function poll(t, context)
		onGameFrame(t, triggerID, context, 1) -- handler ignores the frame number
	end

	-- Puts a unit under construction, on the mocked team, at the given progress.
	local function building(unitID, buildProgress, unitDefID)
		world[unitID] = { beingBuilt = true, buildProgress = buildProgress, defID = unitDefID }
	end

	it("declares its type and parameters", function()
		assert.are.equal('ConstructionProgress', constructionProgress.type)
		local names = {}
		for _, parameter in ipairs(constructionProgress.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.teamID)
		assert.is_true(names.progress)
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.are.same({ 'unitName', 'unitDefName' }, constructionProgress.parameters.requiresOneOf)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		building(100, 0.9, 2)
		poll(trigger({ teamID = 0, progress = 0.5, unitDefName = 'armsolar' }), context)
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function() return false end
		building(100, 0.6, 1)
		poll(trigger({ teamID = 0, progress = 0.5, unitName = 'target' }), context)
		assert.are.equal(0, fired())
	end)

	it("fires when a unit under construction reaches the threshold", function()
		local context, fired = newContext()
		building(100, 0.6, 1)
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = 'armsolar' })
		poll(t, context)
		poll(t, context)
		assert.are.equal(1, fired())
	end)

	it("does not fire while a unit is below the threshold", function()
		local context, fired = newContext()
		building(100, 0.4, 1)
		poll(trigger({ teamID = 0, progress = 0.5, unitDefName = 'armsolar' }), context)
		assert.are.equal(0, fired())
	end)

	it("never fires for a pre-existing unit never seen under construction", function()
		local context, fired = newContext()
		world[100] = { beingBuilt = false, buildProgress = 1.0, defID = 1 }
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = 'armsolar' })
		poll(t, context)
		poll(t, context)
		assert.are.equal(0, fired())
	end)

	it("fires at full progress as a tracked unit finishes (progress = 1.0)", function()
		local context, fired = newContext()
		local t = trigger({ teamID = 0, progress = 1.0, unitDefName = 'armsolar' })
		building(100, 0.9, 1)
		poll(t, context)
		assert.are.equal(0, fired())
		world[100].beingBuilt = false
		world[100].buildProgress = 1.0
		poll(t, context)
		poll(t, context)
		assert.are.equal(1, fired())
	end)

	it("counts a unit once, even if it dips below the threshold and recrosses", function()
		local context, fired = newContext()
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = 'armsolar' })
		building(100, 0.6, 1)
		poll(t, context)
		world[100].buildProgress = 0.3
		poll(t, context)
		world[100].buildProgress = 0.6
		poll(t, context)
		assert.are.equal(1, fired())
	end)

	it("counts each distinct unit as it crosses the threshold over time", function()
		local context, fired = newContext()
		local t = trigger({ teamID = 0, progress = 0.5, unitDefName = 'armsolar' })

		building(100, 0.6, 1)
		poll(t, context)
		assert.are.equal(1, fired())

		building(101, 0.6, 1)
		poll(t, context)
		assert.are.equal(2, fired())

		world[100] = nil
		building(102, 0.6, 1)
		poll(t, context)
		assert.are.equal(3, fired())
	end)

	it("fires for each unit that crosses in the same poll", function()
		local context, fired = newContext()
		building(100, 0.6, 1)
		building(101, 0.8, 1)
		poll(trigger({ teamID = 0, progress = 0.5, unitDefName = 'armsolar' }), context)
		assert.are.equal(2, fired())
	end)
end)
