---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

describe("a group is a value", function()
	it("Group(...) is exported, Grouped takes it, and Transfer.Give takes it", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["units.lua"] = [[
local base = Group("base")
local hub = Spawn(UnitDef("corlab"), "gaia").At(0.4, 0.4).Grouped(base)
Spawn(UnitDef("corllt"), "gaia").At(0.42, 0.4).Grouped("base")
return { base = base, hub = hub }
]],
				["triggers/a.lua"] = 'local U = VFS.Include("modules/missions/t/units.lua")\nWhen(U.hub.IsSpotted(Team.Player)).Do(Transfer.Give(U.base, Team.Player))\n',
			})
			:Arm()
			:Step()
		m:Spot("hub"):Step()
		local give = m:Calls("transfer")[1]
		assert.are.equal("Give", give.method)
		assert.are.equal(2, #give.args[1])
	end)

	it("a plain value exports and reads as itself", function()
		local m = Builders.Mission
			.new()
			:WithSources("t", {
				["units.lua"] = 'local hub = Spawn(UnitDef("corlab"), "gaia").At(0.4, 0.4)\nreturn { hub = hub, enough = 2 }\n',
				["triggers/a.lua"] = 'local Units = VFS.Include("modules/missions/t/units.lua")\nWhen(Team.Player.Has(UnitDef("armpw"), Units.enough)).Do(MatchFlow.Victory(Team.Player))\n',
			})
			:WithUnits(0, "armpw", 1)
			:Arm()
			:Step()
		assert.are.equal(0, #m:Calls("matchflow"))
		m:WithUnits(0, "armpw", 2):Step()
		assert.are.equal("Victory", m:Calls("matchflow")[1].method)
	end)
end)
