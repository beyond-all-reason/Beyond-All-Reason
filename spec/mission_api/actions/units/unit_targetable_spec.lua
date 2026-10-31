local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/units/unit_targetable.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local calls

local function seedUnits(name, ...)
	local builder = Builders.MissionApi.new()
	for _, unitID in ipairs({ ... }) do
		builder:WithTrackedUnit(name, unitID)
	end
	builder:Install()
end

---@return table<number, boolean> unitID -> untargetable flag it was called with
local function untargetableByUnit()
	local byUnit = {}
	for _, call in ipairs(calls) do
		byUnit[call.unitID] = call.untargetable
	end
	return byUnit
end

describe("mission_api.actions.unit_targetable", function()
	before_each(function()
		Builders.MissionApi.new():Install()
		calls = {}
		GG.SetUnitUntargetable = function(unitID, untargetable)
			calls[#calls + 1] = { unitID = unitID, untargetable = untargetable }
		end
	end)

	after_each(function()
		GG.SetUnitUntargetable = nil
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "UnitTargetable",
			unitName = "UnitName!",
			targetable = "Boolean!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("is a no-op for an untracked unit name", function()
			action.actionFunction("unknownUnit", false)

			assert.are.equal(0, #calls)
		end)

		it("makes every tracked unit untargetable when targetable is false", function()
			seedUnits("bots", 101, 102)

			action.actionFunction("bots", false)

			assert.are.equal(2, #calls)
			assert.are.same({ [101] = true, [102] = true }, untargetableByUnit())
		end)

		it("makes every tracked unit targetable when targetable is true", function()
			seedUnits("bots", 101, 102)

			action.actionFunction("bots", true)

			assert.are.equal(2, #calls)
			assert.are.same({ [101] = false, [102] = false }, untargetableByUnit())
		end)

		it("only affects units tracked under the given name", function()
			Builders.MissionApi.new():WithTrackedUnit("bots", 101):WithTrackedUnit("tanks", 202):Install()

			action.actionFunction("bots", false)

			assert.are.equal(1, #calls)
			assert.are.equal(101, calls[1].unitID)
		end)
	end)
end)
