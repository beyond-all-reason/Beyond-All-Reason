---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local function armed(trigger)
	return Builders.Mission.new():WithSources("t", { ["triggers/a.lua"] = trigger }):WithUnits(0, "armpw", 1):Arm()
end

describe("the trigger store beyond Once", function()
	it("Times(n) fires n times and no more, and the pile counts them", function()
		local m = armed('When(Team.Player.Has(UnitDef("armpw"), 1)).Times(2).Do(MatchFlow.Victory(Team.Player))\n')
		m:Step():Step():Step()
		assert.are.equal(2, #m:Calls("matchflow"))
		assert.are.equal(2, m:Param("mission_trigger_fires_t/triggers/a.lua:1"))
		assert.are.equal(1, m:Param("mission_trigger_fired_t/triggers/a.lua:1"))
	end)

	it("Every(seconds) is the floor between fires of a repeating trigger", function()
		local m = armed('When(Team.Player.Has(UnitDef("armpw"), 1)).Every(1).Do(MatchFlow.Victory(Team.Player))\n')
		m:Step():Step()
		assert.are.equal(1, #m:Calls("matchflow"), "the second cadence is inside the floor")
		m:Frame(15 + 30)
		assert.are.equal(2, #m:Calls("matchflow"))
	end)

	it("Once(false) fires every cadence", function()
		local m = armed('When(Team.Player.Has(UnitDef("armpw"), 1)).Once(false).Do(MatchFlow.Victory(Team.Player))\n')
		m:Step():Step():Step()
		assert.are.equal(3, #m:Calls("matchflow"))
	end)

	it("a preserving reload keeps the count, so a spent trigger stays spent", function()
		local m = armed('When(Team.Player.Has(UnitDef("armpw"), 1)).Do(MatchFlow.Victory(Team.Player))\n')
		m:Step():Reload():Step()
		assert.are.equal(1, #m:Calls("matchflow"))
	end)
end)
