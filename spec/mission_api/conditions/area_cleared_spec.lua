local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local ConditionContextBuilder = VFS.Include("spec/builders/condition_context_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")
local summarizeSchema = require("mission_api.schema_spec_helper")

---@type table<integer, integer> unitID -> team and ally team, 1 when not listed
local unitTeams, unitAllyTeams = {}, {}

local env = MissionSpecEnv.new({
	Spring = {
		GetUnitTeam = function(unitID)
			return unitTeams[unitID] or 1
		end,
		GetUnitAllyTeam = function(unitID)
			return unitAllyTeams[unitID] or 1
		end,
	},
})

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load.
MissionApiBuilder.new():Install(env)

local areaCleared = MissionSpecEnv.include(env, "luarules/mission_api/conditions/area_cleared.lua")
local callins = areaCleared.callins

describe("mission_api.triggers.area_cleared", function()
	local area = { x = 0, z = 0, radius = 100 }
	local frameNumber = 0

	before_each(function()
		unitTeams, unitAllyTeams, frameNumber = {}, {}, 0
	end)

	local function teamTrigger()
		return TriggerBuilder.new():WithParameters({ area = area, includeUnit = { teamName = 1 } }):Build()
	end

	local function allianceTrigger()
		return TriggerBuilder.new():WithParameters({ area = area, includeUnit = { allianceName = 1 } }):Build()
	end

	local function newContext()
		local context = ConditionContextBuilder.new():WithEnv(env):Build()
		return context, context.timesFired
	end

	-- Refuses a trigger that fired and does not repeat, as the gadget's ActivateTrigger does.
	local function gatedContext()
		local context = newContext()
		local fires = 0
		context.ActivateTrigger = function(t)
			if t.triggered and not t.settings.repeating then
				return false
			end
			t.triggered = true
			fires = fires + 1
			return true
		end
		return context, function()
			return fires
		end
	end

	local function frame(t, context)
		frameNumber = frameNumber + 1
		callins.GameFrame(t, "t", context, frameNumber)
	end

	local function clearOnce(t, context, unitID)
		callins.UnitsEnteredArea(t, "t", context, { unitID })
		frame(t, context)
		callins.UnitsLeftArea(t, "t", context, { unitID })
		frame(t, context)
	end

	it("declares its type and parameters", function()
		assert.are.same({
			type = "AreaCleared",
			area = "Area!",
			includeUnit = "UnitFilter!",
			excludeUnit = "UnitFilters",
		}, summarizeSchema(areaCleared))
	end)

	it("fires when the last of them is gone, and not before", function()
		local t = teamTrigger()
		local context, fired = newContext()
		callins.UnitsEnteredArea(t, "t", context, { 100, 101 })
		callins.UnitsLeftArea(t, "t", context, { 100 })
		frame(t, context)
		assert.are.equal(0, fired())

		callins.UnitsLeftArea(t, "t", context, { 101 })
		frame(t, context)
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("never fires for an area nobody of theirs was in", function()
		local t = teamTrigger()
		local context, fired = newContext()
		callins.UnitsLeftArea(t, "t", context, { 100 })
		frame(t, context)
		assert.are.equal(0, fired())
	end)

	it("fires once when it does not repeat, and each time when it does", function()
		local once = teamTrigger()
		local context, fired = gatedContext()
		clearOnce(once, context, 100)
		clearOnce(once, context, 101)
		assert.are.equal(1, fired())

		local repeating = teamTrigger()
		repeating.settings.repeating = true
		context, fired = gatedContext()
		clearOnce(repeating, context, 100)
		clearOnce(repeating, context, 101)
		assert.are.equal(2, fired())
	end)

	it("asks a refused trigger again half a second later", function()
		local t = teamTrigger()
		local context = newContext()
		local asked, accept = 0, false
		context.ActivateTrigger = function()
			asked = asked + 1
			return accept
		end
		clearOnce(t, context, 100)
		frame(t, context)
		assert.are.equal(1, asked)

		accept = true
		for _ = 1, 0.5 * Game.gameSpeed do
			frame(t, context)
		end
		assert.are.equal(2, asked)
		frame(t, context)
		assert.are.equal(2, asked)
	end)

	it("with an alliance alone, counts only that alliance's units", function()
		local t = allianceTrigger()
		local context, fired = newContext()
		unitAllyTeams[200] = 0
		callins.UnitsEnteredArea(t, "t", context, { 100, 200 })
		frame(t, context)
		callins.UnitsLeftArea(t, "t", context, { 100 })
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("does not count a unit excludeUnit matches", function()
		local t = TriggerBuilder.new()
			:WithParameters({ area = area, includeUnit = { allianceName = 1 }, excludeUnit = { { teamName = 5 } } })
			:Build()
		local context, fired = newContext()
		unitTeams[300] = 5
		callins.UnitsEnteredArea(t, "t", context, { 100, 300 })
		frame(t, context)
		callins.UnitsLeftArea(t, "t", context, { 100 })
		frame(t, context)
		assert.are.equal(1, fired())
	end)

	it("with an alliance alone, a unit inside that changes sides is gone, or holds the area", function()
		local t = allianceTrigger()
		local context, fired = newContext()
		unitAllyTeams[200] = 0
		callins.UnitsEnteredArea(t, "t", context, { 100, 200 })
		frame(t, context)

		-- The other side's unit is captured, then theirs dies: still held.
		unitAllyTeams[200] = 1
		callins.UnitGiven(t, "t", context)
		callins.UnitsLeftArea(t, "t", context, { 100 })
		frame(t, context)
		assert.are.equal(0, fired())

		unitAllyTeams[200] = 0
		callins.UnitGiven(t, "t", context)
		frame(t, context)
		assert.are.equal(1, fired())
	end)
end)
