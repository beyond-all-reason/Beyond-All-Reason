---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local PRESSURE = [[
local pressure = Scavengers.Skirmish
When(MatchFlow.Started())
	.After(30)
	.Do(pressure.Begin().Against(Team.Player).From(0.85, 0.15).Intensity(0.3))
When(Objective("hold").IsComplete()).Do(pressure.Intensify(0.6)).Do(pressure.Surge())
When(Objective("won").IsComplete()).Do(pressure.End())
]]
local OBJECTIVES = [[
Objective("hold").CompletedWhen(Team.Player.Has(UnitDef("armpw"), 3))
Objective("won").CompletedWhen(Team.Player.Has(UnitDef("armcom"), 2))
]]

local function mission()
	return Builders.Mission
		.new()
		:WithSources("t", { ["objectives.lua"] = OBJECTIVES, ["triggers/p.lua"] = PRESSURE })
		:Arm()
end

local function calls(m, moduleName, method)
	local found = {}
	for _, call in ipairs(m:Calls(moduleName)) do
		if call.method == method then
			found[#found + 1] = call
		end
	end
	return found
end

describe("the mission builder's wave surface", function()
	it("resolves the pack handle and its verbs, and the hold is in frames", function()
		local m = mission()
		local p = m:Triggers()
		local opening
		for _, trigger in ipairs(p) do
			if trigger.filename == "t/triggers/p.lua" and trigger.order == 1 then
				opening = trigger
			end
		end
		assert.are.equal(30 * 30, opening.delayFrames)
	end)

	it("Begin reaches the flavor module with the shape it composed", function()
		local m = mission():Frame(15)
		assert.are.equal(0, #calls(m, "scavengers", "Start"))
		m:Frame(15 + 30 * 30)
		local request = calls(m, "scavengers", "Start")[1].args[1]
		assert.are.equal("scavengers.skirmish", request.pack)
		assert.are.equal("skirmish", request.builder)
		assert.are.equal(0, request.against)
		assert.are.same({ fx = 0.85, fz = 0.15 }, request.origin)
		assert.are.equal(0.3, request.intensity)
	end)

	it("Intensify, Surge and End reach the director by pack", function()
		local m = mission():WithUnits(0, "armpw", 3):Step():Step()
		assert.are.same({ "scavengers.skirmish", 0.6 }, calls(m, "waves", "SetIntensity")[1].args)
		assert.are.equal(1, #calls(m, "waves", "Surge"))
		m:WithUnits(0, "armcom", 2):Step():Step()
		assert.are.equal("scavengers.skirmish", calls(m, "waves", "Stop")[1].args[1])
	end)
end)
