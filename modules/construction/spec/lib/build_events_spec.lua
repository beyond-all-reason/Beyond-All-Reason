local BuildEvents = VFS.Include("modules/construction/lib/build_events.lua")

describe("BuildEvents build-delay debuff", function()
	it("forwards NotifyBuildDelay with unit and frame window", function()
		local args
		BuildEvents.NotifyBuildDelay(42, 100, 190, function(...)
			args = { ... }
		end)
		assert.are.same({ "UnitBuildDelayStarted", 42, 100, 190 }, args)
	end)

	it("forwards NotifyBuildDelayEnd with the unit", function()
		local args
		BuildEvents.NotifyBuildDelayEnd(42, function(...)
			args = { ... }
		end)
		assert.are.same({ "UnitBuildDelayEnded", 42 }, args)
	end)
end)
