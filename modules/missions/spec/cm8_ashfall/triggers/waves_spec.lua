---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local PACK = "scavengers.skirmish"
local OPENING_HOLD = 60 * 30

local function armed()
	local m = Builders.Mission.new():WithMission("cm8_ashfall"):Arm()
	return m, m:Includes()
end

local function beats(m)
	local found = {}
	for _, trigger in ipairs(m:Triggers()) do
		if trigger.filename == "cm8_ashfall/triggers/waves.lua" then
			found[#found + 1] = trigger
		end
	end
	return found
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

describe("cm8_ashfall wave pressure", function()
	it("is four beats, and every verb and noun resolves through the composed sandbox", function()
		assert.are.equal(4, #beats((armed())))
	end)

	it("holds the opening beat back a minute; the rest answer their objective at once", function()
		local b = beats((armed()))
		assert.are.equal(OPENING_HOLD, b[1].delayFrames)
		for i = 2, 4 do
			assert.are.equal(0, b[i].delayFrames or 0)
		end
	end)

	it("opens quiet, aimed at the player, from the northeast", function()
		local m = armed()
		m:Frame(15)
		assert.are.equal(0, #calls(m, "scavengers", "Start"), "nothing starts before the hold elapses")
		m:Frame(15 + OPENING_HOLD)
		local start = calls(m, "scavengers", "Start")
		assert.are.equal(1, #start)
		local request = start[1].args[1]
		assert.are.equal(PACK, request.pack)
		assert.are.equal("scavengers", request.module)
		assert.are.equal("skirmish", request.builder)
		assert.are.equal(0, request.against)
		assert.are.same({ fx = 0.85, fz = 0.15 }, request.origin)
		assert.are.equal(0.3, request.intensity)
	end)

	it("climbs when the outpost is relieved", function()
		local m, Units = armed()
		m:WithUnits(0, "corllt", 4):Spot(Units.hub):Step()
		local dial = calls(m, "waves", "SetIntensity")
		assert.are.equal(1, #dial)
		assert.are.same({ PACK, 0.6 }, dial[1].args)
	end)

	it("spikes when the enclave is found", function()
		local m, Units = armed()
		m:WithUnits(0, "corllt", 4):Spot(Units.hub):Step()
		m:Spot(Units.beacon):Step()
		assert.are.equal(1, #calls(m, "waves", "Surge"))
		local dial = calls(m, "waves", "SetIntensity")
		assert.are.same({ PACK, 1.0 }, dial[#dial].args)
	end)

	it("stops when the commander dies", function()
		local m, Units = armed()
		m:Kill(Units.armadaCommander, 0):Step()
		local stop = calls(m, "waves", "Stop")
		assert.are.equal(1, #stop)
		assert.are.equal(PACK, stop[1].args[1])
	end)
end)
